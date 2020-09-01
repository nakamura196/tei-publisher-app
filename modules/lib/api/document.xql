xquery version "3.1";

module namespace dapi="http://teipublisher.com/api/documents";

import module namespace router="http://exist-db.org/xquery/router" at "/db/apps/oas-router/content/router.xql";
import module namespace config="http://www.tei-c.org/tei-simple/config" at "../../config.xqm";
import module namespace pages="http://www.tei-c.org/tei-simple/pages" at "../pages.xql";
import module namespace pm-config="http://www.tei-c.org/tei-simple/pm-config" at "../../pm-config.xql";
import module namespace tpu="http://www.tei-c.org/tei-publisher/util" at "../util.xql";
import module namespace nav-tei="http://www.tei-c.org/tei-simple/navigation/tei" at "../../navigation-tei.xql";
import module namespace nav="http://www.tei-c.org/tei-simple/navigation" at "../../navigation.xql";
import module namespace query="http://www.tei-c.org/tei-simple/query" at "../../query.xql";
import module namespace mapping="http://www.tei-c.org/tei-simple/components/map" at "../../map.xql";
import module namespace process="http://exist-db.org/xquery/process" at "java:org.exist.xquery.modules.process.ProcessModule";
import module namespace epub="http://exist-db.org/xquery/epub" at "../epub.xql";

declare namespace tei="http://www.tei-c.org/ns/1.0";

declare function dapi:html($request as map(*)) {
    let $doc := xmldb:decode($request?parameters?id)
    let $odd := head(($request?parameters?odd, $config:odd))
    return
        if ($doc) then
            let $xml := config:get-document($doc)/*
            let $config := tpu:parse-pi(root($xml), ())
            let $out := $pm-config:web-transform($xml, map { "root": $xml }, $config?odd)
            let $styles := if (count($out) > 1) then $out[1] else ()
            return
                dapi:postprocess(($out[2], $out[1])[1], $styles, $odd)
        else
            <p>No document specified</p>
};

declare %private function dapi:postprocess($nodes as node()*, $styles as element()?, $odd as xs:string) {
    let $oddName := replace($odd, "^.*/([^/\.]+)\.?.*$", "$1")
    for $node in $nodes
    return
        typeswitch($node)
            case element(head) return
                element { node-name($node) } {
                    $node/@*,
                    $node/node(),
                    <link rel="stylesheet" type="text/css" href="../transform/{replace($oddName, "^(.*)\.odd$", "$1")}-print.css" media="print"/>,
                    $styles
                }
            case element() return
                element { node-name($node) } {
                    $node/@*,
                    dapi:postprocess($node/node(), $styles, $odd)
                }
            default return
                $node
};

declare function dapi:latex($request as map(*)) {
    let $id := xmldb:decode($request?parameters?id)
    let $token := $request?parameters?token
    let $source := $request?parameters?source
    return (
        if ($token) then
            response:set-cookie("simple.token", $token)
        else
            (),
        if ($id) then
            let $log := util:log("INFO", "Loading doc: " || $id)
            let $xml := config:get-document($id)/*
            let $config := tpu:parse-pi(root($xml), ())
            let $options :=
                map {
                    "root": $xml,
                    "image-dir": config:get-repo-dir() || "/" ||
                        substring-after($config:data-root[1], $config:app-root) || "/"
                }
            let $tex := string-join($pm-config:latex-transform($xml, $options, $config?odd))
            let $file :=
                replace($id, "^.*?([^/]+)$", "$1") || format-dateTime(current-dateTime(), "-[Y0000][M00][D00]-[H00][m00]")
            return
                if ($source) then
                    $tex
                else
                    let $serialized := file:serialize-binary(util:string-to-binary($tex), $config:tex-temp-dir || "/" || $file || ".tex")
                    let $options :=
                        <option>
                            <workingDir>{$config:tex-temp-dir}</workingDir>
                        </option>
                    let $output :=
                        for $i in 1 to 3
                        return
                            process:execute(
                                ( $config:tex-command($file) ), $options
                            )
                    return
                        if ($output[last()]/@exitCode < 2) then
                            let $pdf := file:read-binary($config:tex-temp-dir || "/" || $file || ".pdf")
                            return
                                response:stream-binary($pdf, "media-type=application/pdf", $file || ".pdf")
                        else
                            $output
        else
            <p>No document specified</p>
    )
};

declare function dapi:epub($request as map(*)) {
    let $id := xmldb:decode($request?parameters?id)
    let $work := config:get-document($id)
    let $entries := dapi:work2epub($id, $work, $request?parameters?lang)
    return
        (
            if ($request?parameters?token) then
                response:set-cookie("simple.token", $request?parameters?token)
            else
                (),
            response:set-header("Content-Disposition", concat("attachment; filename=", concat($id, '.epub'))),
            response:stream-binary(
                compression:zip( $entries, true() ),
                'application/epub+zip',
                concat($id, '.epub')
            )
        )
};

declare %private function dapi:work2epub($id as xs:string, $work as document-node(), $lang as xs:string?) {
    let $config := $config:epub-config($work, $lang)
    let $oddName := replace($config:odd, "^([^/\.]+).*$", "$1")
    let $cssDefault := util:binary-to-string(util:binary-doc($config:output-root || "/" || $oddName || ".css"))
    let $cssEpub := util:binary-to-string(util:binary-doc($config:app-root || "/resources/css/epub.css"))
    let $css := $cssDefault || 
        "&#10;/* styles imported from epub.css */&#10;" || 
        $cssEpub
    return
        epub:generate-epub($config, $work/*, $css, $id)
};

declare function dapi:get-fragment($request as map(*)) {
    let $doc := xmldb:decode-uri($request?parameters?doc)
    let $view := head(($request?parameters?view, $config:default-view))
    let $xml :=
        if ($request?parameters?xpath) then
            for $document in config:get-document($doc)
            let $namespace := namespace-uri-from-QName(node-name($document/*))
            let $xquery := "declare default element namespace '" || $namespace || "'; $document" || $request?parameters?xpath
            let $data := util:eval($xquery)
            return
                if ($data) then
                    pages:load-xml($data, $view, $request?parameters?root, $doc)
                else
                    ()

        else if (exists($request?parameters?id)) then (
            for $document in config:get-document($doc)
            let $config := tpu:parse-pi($document, $view)
            let $data :=
                if (count($request?parameters?id) = 1) then
                    nav:get-section-for-node($config, $document/id($request?parameters?id))
                else
                    let $ms1 := $document/id($request?parameters?id[1])
                    let $ms2 := $document/id($request?parameters?id[2])
                    return
                        if ($ms1 and $ms2) then
                            nav-tei:milestone-chunk($ms1, $ms2, $document/tei:TEI)
                        else
                            ()
            return
                map {
                    "config": map:merge(($config, map { "context": $document })),
                    "odd": $config?odd,
                    "view": $config?view,
                    "data": $data
                }
        ) else
            pages:load-xml($view, $request?parameters?root, $doc)
    return
        if ($xml?data) then
            let $userParams :=
                map:merge((
                    request:get-parameter-names()[starts-with(., 'user')] ! map { substring-after(., 'user.'): request:get-parameter(., ()) },
                    map { "webcomponents": 6 }
                ))
            let $mapped :=
                if ($request?parameters?map) then
                    let $mapFun := function-lookup(xs:QName("mapping:" || $request?parameters?map), 2)
                    let $mapped := $mapFun($xml?data, $userParams)
                    return
                        $mapped
                else
                    $xml?data
            let $data :=
                if (empty($request?parameters?xpath) and $request?parameters?highlight and exists(session:get-attribute($config:session-prefix || ".query"))) then
                    query:expand($xml?config, $mapped)[1]
                else
                    $mapped
            let $content :=
                if (not($view = "single")) then
                    pages:get-content($xml?config, $data)
                else
                    $data

            let $html :=
                typeswitch ($mapped)
                    case element() | document-node() return
                        pages:process-content($content, $xml?data, $xml?config, $userParams)
                    default return
                        $content
            let $transformed := dapi:extract-footnotes($html[1])
            let $doc := replace($doc, "^.*/([^/]+)$", "$1")
            return
                if ($request?parameters?format = "html") then
                    router:response(200, "text/html", $transformed?content)
                else
                    router:response(200, "application/json",
                        map {
                            "format": $request?parameters?format,
                            "view": $view,
                            "doc": $doc,
                            "root": $request?parameters?root,
                            "odd": $xml?config?odd,
                            "next":
                                if ($view != "single") then
                                    let $next := $config:next-page($xml?config, $xml?data, $view)
                                    return
                                        if ($next) then
                                            util:node-id($next)
                                        else ()
                                else
                                    (),
                            "previous":
                                if ($view != "single") then
                                    let $prev := $config:previous-page($xml?config, $xml?data, $view)
                                    return
                                        if ($prev) then
                                            util:node-id($prev)
                                        else
                                            ()
                                else
                                    (),
                            "switchView":
                                if ($view != "single") then
                                    let $node := pages:switch-view-id($xml?data, $view)
                                    return
                                        if ($node) then
                                            util:node-id($node)
                                        else
                                            ()
                                else
                                    (),
                            "content": serialize($transformed?content,
                                <output:serialization-parameters xmlns:output="http://www.w3.org/2010/xslt-xquery-serialization">
                                <output:indent>no</output:indent>
                                <output:method>html5</output:method>
                                    </output:serialization-parameters>),
                            "footnotes": $transformed?footnotes,
                            "userParams": $userParams
                        }
                    )
        else
            map { "error": "Not found" }
};

declare %private function dapi:extract-footnotes($html as element()*) {
    map {
        "footnotes": $html/div[@class="footnotes"],
        "content":
            element { node-name($html) } {
                $html/@*,
                $html/node() except $html/div[@class="footnotes"]
            }
    }
};