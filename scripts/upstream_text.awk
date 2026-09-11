# POSIX awk: bounded link extraction and TSV -> JSON output. Never parses JSON.
function die(s) { print "Error: " s > "/dev/stderr"; exit 1 }
function quote(s,    i,c,out) {
    out="\""
    for(i=1;i<=length(s);i++) {
        c=substr(s,i,1)
        if(c=="\\" || c=="\"") out=out "\\" c
        else if(c=="\n") out=out "\\n"
        else if(c=="\r") out=out "\\r"
        else if(c=="\t") out=out "\\t"
        else if(c ~ /[[:cntrl:]]/) die("Control character in JSON output")
        else out=out c
    }
    return out "\""
}
function append(s,v) { return s (s=="" ? "" : ",") v }
function pathok(s) { return s!="" && s!="-" && s !~ /[\\[:cntrl:]]/ && s !~ /^\// && ("/" s "/") !~ /\/\.\.?\// }
function addlink(s) {
    sub(/[.,;*]+$/, "", s)
    if(s!="" && s !~ /[[:cntrl:]]/ && !links[s]++) print s
}
function extract(s,    t,p) {
    t=s
    while(match(t,/\]\(<?[^[:space:]>)]*/)) {
        p=substr(t,RSTART,RLENGTH); sub(/^\]\(<?/,"",p); addlink(p); t=substr(t,RSTART+RLENGTH)
    }
    t=s
    if(match(t,/^[[:space:]]*\[[^]]+\]:[[:space:]]*<?[^[:space:]>]+/)) {
        p=substr(t,RSTART,RLENGTH); sub(/^[[:space:]]*\[[^]]+\]:[[:space:]]*<?/,"",p); addlink(p)
    }
    t=s
    while(match(t,/(href|src)=["'][^"']+["']/)) {
        p=substr(t,RSTART,RLENGTH); sub(/^[^=]+=["']/,"",p); sub(/["']$/,"",p); addlink(p); t=substr(t,RSTART+RLENGTH)
    }
    t=s
    while(match(t,/https?:\/\/[^[:space:]<>"')]+/)) {
        addlink(substr(t,RSTART,RLENGTH)); t=substr(t,RSTART+RLENGTH)
    }
}
function decode(s,    i,h,a,b,out) {
    for(i=1;i<=length(s);i++) {
        h=tolower(substr(s,i+1,2))
        if(substr(s,i,1)=="%" && h ~ /^[0-9a-f][0-9a-f]$/) {
            a=index("0123456789abcdef",substr(h,1,1))-1; b=index("0123456789abcdef",substr(h,2,1))-1
            if(a*16+b<32 || a*16+b==127) return "/outside-scope"
            out=out sprintf("%c",a*16+b); i+=2
        } else out=out substr(s,i,1)
    }
    return out
}
function normalize(s,    n,a,b,i,k,out) {
    n=split(s,a,"/"); k=0
    for(i=1;i<=n;i++) {
        if(a[i]=="" || a[i]==".") continue
        if(a[i]==".." && k>0 && b[k]!="..") k--
        else b[++k]=a[i]
    }
    for(i=1;i<=k;i++) out=out (i==1 ? "" : "/") b[i]
    return (s ~ /^\// ? "/" : "") out
}
function resolve(href,    p,target,status,parent) {
    p=href; sub(/[#?].*$/,"",p); if(p=="") return
    if(kind=="threejs" && p ~ /^https?:\/\/threejs\.org\/docs\/pages\//) {
        sub(/^https?:\/\/threejs\.org\//,"",p); target=normalize(decode(p))
    } else if(p ~ /^[A-Za-z][A-Za-z0-9+.-]*:/ || p ~ /^\/\//) target="-"
    else if(p ~ /^\//) target=decode(p)
    else {
        parent=source; sub(/[^\/]+$/,"",parent); target=normalize(parent decode(p))
    }
    if(kind=="threejs" && target ~ /\.html$/) target=target ".md"
    if(target=="-") status="external"
    else if(!pathok(target)) status="outside_scope"
    else if(!(target in tree)) status="missing"
    else if(target !~ /\.(md|mdx|html|txt|json|yaml|yml|png|svg|webp|jpg|jpeg)$/ || (kind=="threejs" && target !~ /^docs\/pages\//)) status="outside_scope"
    else status=(level<depth ? "bundled" : "depth_limit")
    print "ref", source, href, target, status, "-"
}
function validate(    s) {
    if($1=="meta") {
        if(NF!=3 || $2 !~ /^(repository|commit|version|revision|license|scope|reference_depth)$/ || meta[$2]++) die("Invalid/duplicate metadata")
        if($2=="commit" && ($3 !~ /^[0-9a-f]+$/ || length($3)!=40)) die("Invalid commit")
        if($2=="reference_depth" && $3 !~ /^[0-3]$/) die("Invalid reference depth")
    } else if($1=="root") {
        if(NF!=2 || !pathok($2) || roots[$2]++) die("Invalid/duplicate root")
    } else if($1=="file") {
        if(NF!=4 || !pathok($2) || !pathok($4) || files[$2]++ || $3 !~ /^[0-9a-f]+$/ || length($3)!=64) die("Invalid/duplicate file")
    } else if($1=="ref") {
        if(NF!=6 || !pathok($2) || $3=="" || refs[$2 SUBSEP $3]++ || $5 !~ /^(bundled|external|depth_limit|outside_scope)$/) die("Invalid/duplicate reference")
        if($5=="bundled") {
            if(!pathok($4) || ($6!="-" && !pathok($6))) die("Unsafe bundled reference")
            bundled[$6=="-" ? $4 : $6]=1
        }
    } else die("Unknown TSV record")
    s=$0; gsub(/\t/,"",s); if(s ~ /[[:cntrl:]]/) die("Control character in TSV")
}
BEGIN { FS=OFS="\t"; mode=ENVIRON["MODE"]; kind=ENVIRON["KIND"]; source=ENVIRON["SOURCE_PATH"]; level=ENVIRON["LEVEL"]+0; depth=ENVIRON["DEPTH"]+0 }
mode=="links" { extract($0); next }
mode=="resolve" {
    if(FILENAME==ARGV[1]) tree[$2]=$1
    else resolve($0)
    next
}
mode=="finalize" {
    if(FILENAME==ARGV[1]) { seen[$0]=1; next }
    if($4 in seen) {
        $5="bundled"
        if(kind=="threejs") { $6=$4; sub(/^.*\//,"",$6) }
    }
    print; next
}
mode=="validate" { validate(); next }
mode=="json" {
    if($1=="meta") metadata=append(metadata,quote($2) ":" ($2=="reference_depth" ? $3 : quote($3)))
    if($1=="root") rootjson=append(rootjson,quote($2))
    if($1=="file") filejson=append(filejson,quote($2) ":" (kind=="threejs" ? "{\"path\":" quote($4) ",\"sha256\":" quote($3) "}" : quote($3)))
    if($1=="ref") refjson=append(refjson,"{\"source\":" quote($2) ",\"href\":" quote($3) ",\"target\":" ($4=="-" ? "null" : quote($4)) ",\"status\":" quote($5) ($6=="-" ? "" : ",\"local\":" quote($6)) "}")
    next
}
mode=="api" { apijson=append(apijson,"{\"url\":" quote($1) ",\"status\":" quote($2) ",\"resolved_url\":" quote($3) ",\"availability\":" quote($4) ",\"storage\":\"online_only\"}"); next }
mode=="report" {
    if(FILENAME==ARGV[2]) {
        apijson=append(apijson,"{\"url\":" quote($1) ",\"status\":" quote($2) ",\"resolved_url\":" quote($3) ",\"availability\":" quote($4) ",\"storage\":\"online_only\"}")
        if($4!="reachable") warnings=append(warnings,quote("Online reference " $4 ": " $1))
    } else if($1=="status") status=$2
    else if($1=="source") { kinds[++nk]=$2; from[$2]=$3; to[$2]=$4 }
    else if($1=="references") counts[$2]=append(counts[$2],quote($3) ":" $4)
    else if($1 ~ /^(added|changed|removed)$/) changes[$2,$1]=append(changes[$2,$1],quote($3))
    next
}
END {
    if(mode=="validate") {
        for(s in bundled) if(!(s in files)) die("Missing bundled reference: " s)
        if(!meta["commit"] || !meta["repository"] || !meta["reference_depth"]) die("Missing metadata")
    }
    if(mode=="json") print "{" metadata ",\"roots\":[" rootjson "],\"files\":{" filejson "},\"references\":[" refjson "]}"
    if(mode=="api") print "[" apijson "]"
    if(mode=="report") {
        for(i=1;i<=nk;i++) {
            k=kinds[i]
            sources=append(sources,quote(k) ":{\"from\":" quote(from[k]) ",\"to\":" quote(to[k]) ",\"added\":[" changes[k,"added"] "],\"removed\":[" changes[k,"removed"] "],\"changed\":[" changes[k,"changed"] "],\"reference_counts\":{" counts[k] "}}")
        }
        print "{\"status\":" quote(status) ",\"sources\":{" sources "},\"official_api_links\":[" apijson "],\"warnings\":[" warnings "],\"report\":" quote(ENVIRON["REPORT_PATH"]) "}"
    }
}
