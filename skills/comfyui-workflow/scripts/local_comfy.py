#!/usr/bin/env python3
"""Read a loopback ComfyUI and inspect or preserve editable workflow files."""

import argparse
import hashlib
import ipaddress
import json
from pathlib import Path
import sys
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urlsplit
from urllib.request import HTTPRedirectHandler, ProxyHandler, build_opener


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise ValueError("Local requests must not redirect")


class LocalComfy:
    def __init__(self, url):
        parts = urlsplit(url)
        host = parts.hostname
        if host == "localhost":
            host = "127.0.0.1"
        if (parts.scheme not in ("http", "https") or not host
                or parts.username or parts.password or parts.query or parts.fragment
                or parts.path not in ("", "/")):
            raise ValueError("Use a loopback HTTP(S) URL without credentials or a path")
        if not ipaddress.ip_address(host).is_loopback:
            raise ValueError("Only loopback ComfyUI instances are supported")
        host = f"[{host}]" if ":" in host else host
        self.url = f"{parts.scheme}://{host}" + (f":{parts.port}" if parts.port else "")
        self.opener = build_opener(ProxyHandler({}), NoRedirect())

    def get(self, route):
        with self.opener.open(self.url + route, timeout=15) as response:
            data = response.read(32 * 1024 * 1024 + 1)
        if len(data) > 32 * 1024 * 1024:
            raise ValueError("Response exceeds 32 MiB; query a specific node")
        return json.loads(data)

    def node(self, name):
        try:
            return self.get("/object_info/" + quote(name, safe="")).get(name)
        except HTTPError as exc:
            if exc.code == 404:
                return None
            raise


def load_workflow(path):
    data = Path(path).read_bytes()
    graph = json.loads(data)
    if not isinstance(graph, dict) or not isinstance(graph.get("nodes"), list):
        raise ValueError("Expected editable UI JSON with a nodes array, not API JSON")
    if not isinstance(graph.get("links"), list):
        raise ValueError("Expected a UI links array")
    return data, graph


def node_policy(schema):
    module = schema.get("python_module") or ""
    category = (schema.get("category") or "").lower()
    if (schema.get("api_node") or module.startswith("comfy_api_nodes")
            or category.startswith("api node")):
        return "api_node"
    if module == "nodes" or module.startswith("comfy_extras."):
        return "core_reported"
    return "review_required"


def inspect_graph(graph, client=None):
    errors, limitations, review = [], [], []
    nodes, links = {}, {}
    for node in graph["nodes"]:
        if not isinstance(node, dict) or type(node.get("id")) not in (int, str):
            raise ValueError("Each UI node needs a string or integer id")
        key = str(node["id"])
        if key in nodes:
            errors.append(f"Duplicate node id: {key}")
        if not isinstance(node.get("type"), str) or not node["type"]:
            errors.append(f"Missing node type: {key}")
        nodes[key] = node
    if not nodes:
        errors.append("Workflow has no nodes")
    if graph.get("version") not in (0.4, 1):
        limitations.append("Unrecognized UI version; only basic graph checks performed")
    if graph.get("definitions") or graph.get("reroutes"):
        limitations.append("Subgraphs/reroutes require validation in the installed frontend")

    def slots(node, field):
        value = node.get(field, [])
        if not isinstance(value, list) or any(not isinstance(v, dict) for v in value):
            raise ValueError(f"Invalid {field} slots on node {node['id']}")
        return value

    for link in graph["links"]:
        if isinstance(link, list) and len(link) == 6:
            link_id, origin, output_slot, target, input_slot, _ = link
        elif isinstance(link, dict):
            link_id, origin, output_slot, target, input_slot = (
                link[k] for k in ("id", "origin_id", "origin_slot", "target_id", "target_slot"))
        else:
            raise ValueError("Expected six-item or object UI link")
        if any(type(v) not in (int, str) for v in (link_id, origin, target)):
            raise ValueError("Link/node IDs must be strings or integers")
        key, origin, target = str(link_id), str(origin), str(target)
        if key in links:
            errors.append(f"Duplicate link id: {key}")
        links[key] = (origin, output_slot, target, input_slot)
        if origin not in nodes or target not in nodes:
            errors.append(f"Link {key}: missing endpoint node")
            continue
        for node_id, field, slot in ((origin, "outputs", output_slot), (target, "inputs", input_slot)):
            ports = slots(nodes[node_id], field)
            if type(slot) is not int or not 0 <= slot < len(ports):
                errors.append(f"Link {key}: invalid {field} slot on node {node_id}")
                continue
            refs = (ports[slot].get("links") or []) if field == "outputs" else [ports[slot].get("link")]
            if str(link_id) not in [str(v) for v in refs]:
                errors.append(f"Link {key}: missing {field} back-reference on node {node_id}")
    for key, node in nodes.items():
        for field in ("inputs", "outputs"):
            for index, port in enumerate(slots(node, field)):
                refs = (port.get("links") or []) if field == "outputs" else [port.get("link")]
                for ref in refs:
                    if ref is None:
                        continue
                    edge = links.get(str(ref))
                    endpoint = (edge[0], edge[1]) if edge and field == "outputs" else ((edge[2], edge[3]) if edge else None)
                    if endpoint != (key, index):
                        errors.append(f"Node {key}: {field}[{index}] has inconsistent link {ref}")

    classes = sorted({n.get("type") for n in nodes.values() if isinstance(n.get("type"), str)})
    basic_structure_ok = not errors
    missing, api_nodes = [], []
    if client:
        for name in classes:
            schema = client.node(name)
            if schema is None:
                missing.append(name)
            elif node_policy(schema) == "api_node":
                api_nodes.append(name)
            elif node_policy(schema) == "review_required":
                review.append(name)
        if missing:
            errors.append("Unavailable backend classes (may include frontend-only nodes): " + ", ".join(missing))
        if api_nodes:
            errors.append("Known API nodes violate local-only policy: " + ", ".join(api_nodes))
    else:
        limitations.append("Node availability and local-only node policy were not checked")
    limitations.append("Not checked: full UI schema, widgets, required inputs, model compatibility, execution, VRAM, output quality")
    return {"basic_structure_ok": basic_structure_ok,
            "live_checked": client is not None, "node_count": len(nodes), "link_count": len(links),
            "classes": classes, "review_nodes": review, "errors": errors, "limitations": limitations}


def save_bytes(path, data):
    output = Path(path)
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("xb") as stream:
        stream.write(data)
    return str(output.resolve())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", default="http://127.0.0.1:8188")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("system")
    commands.add_parser("templates")
    for name in ("nodes", "models"):
        command = commands.add_parser(name)
        command.add_argument("--query", default="")
        command.add_argument("--limit", type=int, default=8)
        if name == "models":
            command.add_argument("--folder")
    commands.add_parser("node").add_argument("name")
    command = commands.add_parser("inspect")
    command.add_argument("path")
    command.add_argument("--live", action="store_true")
    command = commands.add_parser("save")
    command.add_argument("path")
    command.add_argument("--output", required=True)
    args = parser.parse_args()
    try:
        if args.command in ("inspect", "save"):
            data, graph = load_workflow(args.path)
            result = inspect_graph(graph, LocalComfy(args.url) if getattr(args, "live", False) else None)
            result["sha256"] = hashlib.sha256(data).hexdigest()
            if args.command == "save" and not result["errors"]:
                result["saved"] = save_bytes(args.output, data)
            code = 2 if result["errors"] else 0
        else:
            client = LocalComfy(args.url)
            if args.command in ("system", "templates"):
                result = client.get("/system_stats" if args.command == "system" else "/workflow_templates")
            elif args.command == "node":
                result = client.node(args.name)
                if result is None:
                    raise ValueError(f"Node unavailable: {args.name}")
            else:
                if not 1 <= args.limit <= 50:
                    raise ValueError("limit must be between 1 and 50")
                query = args.query.casefold()
                if args.command == "nodes":
                    rows = [{"name": k, "display_name": v.get("display_name") or k,
                             "category": v.get("category"), "python_module": v.get("python_module"),
                             "policy": node_policy(v)}
                            for k, v in client.get("/object_info").items()
                            if query in " ".join((k, v.get("display_name") or "", v.get("category") or "")).casefold()]
                    rows.sort(key=lambda row: row["name"])
                else:
                    route = "/models" + ("/" + quote(args.folder, safe="") if args.folder else "")
                    rows = sorted(x for x in client.get(route) if query in x.casefold())
                result = {"total": len(rows), "items": rows[:args.limit], "truncated": len(rows) > args.limit}
            result = {"server": client.url, "data": result}
            code = 0
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return code
    except (OSError, ValueError, KeyError, TypeError, URLError) as exc:
        print(json.dumps({"error": str(exc)}, ensure_ascii=False))
        return 2


if __name__ == "__main__":
    sys.exit(main())
