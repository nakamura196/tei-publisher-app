xquery version "3.1";

module namespace app = "teipublisher.com/app";

import module namespace templates = "http://exist-db.org/xquery/templates";
import module namespace config = "http://www.tei-c.org/tei-simple/config" at "config.xqm";
import module namespace dbutil = "http://exist-db.org/xquery/dbutil";
import module namespace obe = "http://exist-db.org/apps/teipublisher/obe" at "odd-by-example.xql";

declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare namespace expath = "http://expath.org/ns/pkg";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare variable $app:EXIDE :=
let $path := collection(repo:get-root())//expath:package[@name = "http://exist-db.org/apps/eXide"]
return
    if ($path) then
        substring-after(util:collection-name($path), repo:get-root())
    else
        ();

declare
%templates:wrap
function app:odd-table($node as node(), $model as map(*), $odd as xs:string?) {
    let $odd := ($odd, session:get-attribute($config:session-prefix || ".odd"), $config:odd)[1]
    let $user := request:get-attribute($config:login-domain || ".user")
    return
        dbutil:scan-resources(xs:anyURI($config:odd-root), function ($resource) {
            if (ends-with($resource, ".odd")) then
                let $name := replace($resource, "^.*/([^/\.]+)\..*$", "$1")
                let $displayName := (
                doc($resource)/tei:TEI/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title[@type = "short"],
                doc($resource)/tei:TEI/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title,
                $name
                )[1]
                return
                    <tr>
                        <td>
                            {
                                if ($odd = $name || ".odd") then
                                    <a href="?odd={$name}.odd">
                                        <i class="material-icons">check_box</i>
                                    </a>
                                else
                                    <a href="?odd={$name}.odd">
                                        <i class="material-icons">check_box_outline_blank</i>
                                    </a>
                            }
                        </td>
                        <td><a href="odd-editor.html?odd={$name}.odd" target="_new">{string($displayName)}</a></td>
                        <td>
                            {
                                let $outputPath := $config:output-root || "/" || $name
                                let $xqlWebAvail := util:binary-doc-available($outputPath || "-web.xql")
                                let $xqlFoAvail := util:binary-doc-available($outputPath || "-print.xql")
                                let $cssAvail := util:binary-doc-available($outputPath || ".css")
                                return
                                    if ($user) then
                                        templates:process(
                                        <div class="btn-group btn-group-sm" role="group">
                                            <a class="btn btn-default recompile" title="Regenerate"
                                                href="?source={$name}.odd&amp;odd={$odd}">
                                                <i class="material-icons">update</i>
                                            </a>
                                            <a class="btn btn-default delete-odd" title="Delete"
                                                href="{$name}.odd">
                                                <i class="material-icons">delete</i>
                                            </a>
                                            <div class="btn-group">
                                                <button type="button" class="btn btn-default dropdown-toggle" data-toggle="dropdown" aria-expanded="false">
                                                    <i class="material-icons">code</i>
                                                    <span class="caret"/>
                                                </button>
                                                <ul class="dropdown-menu" role="menu">
                                                    <li>
                                                        <a data-template="app:load-source"
                                                            href="{substring-after($resource, $config:app-root)}">
                                                            <i class="material-icons">edit</i> ODD</a>
                                                    </li>
                                                    <li>
                                                        <a data-template="app:load-source"
                                                            href="{substring-after($config:output-root, $config:app-root)}/{$name}-web.xql">
                                                            {
                                                                if ($xqlWebAvail) then
                                                                    ()
                                                                else
                                                                    attribute disabled {"disabled"}
                                                            }
                                                            <i class="material-icons">edit</i> Web XQL</a>
                                                    </li>
                                                    <li>
                                                        <a data-template="app:load-source"
                                                            href="{substring-after($config:output-root, $config:app-root)}/{$name}-print.xql">
                                                            {
                                                                if ($xqlFoAvail) then
                                                                    ()
                                                                else
                                                                    attribute disabled {"disabled"}
                                                            }
                                                            <i class="material-icons">edit</i> FO XQL</a>
                                                    </li>
                                                    <li>
                                                        <a data-template="app:load-source"
                                                            href="{substring-after($config:output-root, $config:app-root)}/{$name}-latex.xql">
                                                            {
                                                                if ($xqlFoAvail) then
                                                                    ()
                                                                else
                                                                    attribute disabled {"disabled"}
                                                            }
                                                            <i class="material-icons">edit</i> LaTeX XQL</a>
                                                    </li>
                                                    <li>
                                                        <a data-template="app:load-source"
                                                            href="{substring-after($config:output-root, $config:app-root)}/{$name}.css">
                                                            {
                                                                if ($cssAvail) then
                                                                    ()
                                                                else
                                                                    attribute disabled {"disabled"}
                                                            }
                                                            <i class="material-icons">edit</i> CSS</a>
                                                    </li>
                                                </ul>
                                            </div>
                                        </div>,
                                        $model
                                        )
                                    else
                                        ()
                            }
                        </td>
                    </tr>
            else
                ()
        })
};

declare
%templates:default("odd", "teipublisher.odd")
function app:odd-editor($node as node(), $model as map(*), $odd as xs:string, $root as xs:string?, $output-root as xs:string?,
$output-prefix as xs:string?) {
    let $root := ($root, $config:odd-root)[1]
    return
        <pb-odd-editor output-root="{($output-root, $config:app-root || "/transform")[1]}"
            root-path="{$root}"
            output-prefix="{($output-prefix, "transform")[1]}"
            odd="{$odd}">
        {
            $node/@*,
            templates:process($node/node(), $model)
        }
        </pb-odd-editor>
};


declare
%templates:wrap
%templates:default("odd", "teipublisher.odd")
function app:form-odd-select($node as node(), $model as map(*), $odd as xs:string, $root as xs:string?) {
    let $oddRoot := ($root, $config:odd-root)[1]
    return
        dbutil:scan-resources(xs:anyURI($oddRoot), function ($resource) {
            if (ends-with($resource, ".odd")) then
                let $name := replace($resource, "^.*/([^/\.]+)\..*$", "$1")
                let $displayname :=
                for $display in $name
                let $rev-date := data(doc($resource)//tei:revisionDesc/tei:change/@when)[1]
                let $title := (
                doc($resource)/tei:TEI/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title[@type = "short"],
                doc($resource)/tei:TEI/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title/text(),
                $name
                )[1]
                return
                    $title || " [" || $rev-date || "]"
                let $file := replace($resource, "^.*/([^/]+)$", "$1")
                return
                    <paper-item value="{$file}">
                        {
                            if ($odd and $file = $odd) then
                                attribute selected {"selected"}
                            else
                                (),
                            string($displayname)
                        }
                    </paper-item>
            else
                ()
        })
};

declare function app:odd-documentation($node as node()) as node()* {

    (:~ creates data rows for documenting different odd choices,
:  located in: doc('/data/doc/documentation.xml')//tei:table[@xml:id='odd-choice']
:)
    dbutil:scan-resources(xs:anyURI($config:odd-root), function ($resource) {

        let $file := replace($resource, "^.*/([^/\.]+)\..*$", "$1")
        let $title := doc($resource)//tei:titleStmt/tei:title/string()
        let $last-rev := data(doc($resource)//tei:revisionDesc/tei:change/@when)[1]
        let $src := substring-before(data(doc($resource)//tei:schemaSpec/@source), '.odd')
        let $publisher := doc($resource)//tei:publicationStmt/tei:publisher/string()

        return
            if (ends-with($resource, ".odd"))
            then
                (<row>
                    <cell>{$file}</cell>
                    <cell>{$title}</cell>
                    <cell>{$last-rev}</cell>
                    <cell>{$src}</cell>
                    <cell>{$publisher}</cell>
                </row>)
            else
                ()
    })
};

declare function app:load-source($node as node(), $model as map(*)) as node()* {
    let $href := $node/@href/string()
    let $link :=
    let $path := string-join(
    (request:get-context-path(), request:get-attribute("$exist:prefix"), $app:EXIDE,
    "index.html?open=" || templates:get-app-root($model) || "/" || $href)
    , "/"
    )
    return
        replace($path, "/+", "/")
    return
        element {node-name($node)} {
            attribute href {$link},
            attribute target {"eXide"},
            attribute class {"eXide-open " || $node/@class},
            attribute data-exide-open {templates:get-app-root($model) || "/" || $href},
            $node/@* except ($node/@href, $node/@class),
            $node/node()
        }
};

declare
%templates:wrap
function app:action($node as node(), $model as map(*), $delete as xs:string?, $action as xs:string?, $new_odd as xs:string?, $title as xs:string?, $build as xs:string?,
    $odd_base as xs:string?) {
        switch ($action)
            case "build-odd" return
                let $docs := request:get-parameter("docs[]", ())
                return
                    <div class="panel panel-primary alert-message" role="alert">
                        <div class="panel-heading"><h3 class="panel-title">Generated ODD from Example</h3></div>
                        <div class="panel-body">
                            <p>Generated: { obe:process-example($config:data-default, $new_odd, $odd_base, $docs, $title) }</p>
                            <p>using base ODD: {$odd_base}</p>
                        </div>
                    </div>
            case "create-odd"
                return
                    <div class="panel panel-primary alert-message" role="alert">
                        <div class="panel-heading"><h3 class="panel-title">Generated Files</h3></div>
                        <div class="panel-body">
                            <ul class="list-group">
                                {
                                    let $template := doc($config:odd-root || "/template.odd.xml")
                                    let $parsed := document {app:parse-template($template, $new_odd, $title)}
                                    return
                                        xmldb:store($config:odd-root, $new_odd || ".odd", $parsed, "text/xml")
                                }
                            </ul>
                        </div>
                    </div>
            default return
                ()
};

declare %private function app:parse-template($nodes as node()*, $odd as xs:string, $title as xs:string?) {
    for $node in $nodes
    return
        typeswitch ($node)
            case document-node()
                return
                    app:parse-template($node/node(), $odd, $title)
            case element(tei:schemaSpec)
                return
                    element {node-name($node)} {
                        $node/@*,
                        attribute ident {$odd},
                        app:parse-template($node/node(), $odd, $title)
                    }
            case element(tei:title)
                return
                    element {node-name($node)} {
                        $node/@*,
                        $title
                    }
            case element(tei:change)
                return
                    element {node-name($node)} {
                        attribute when {current-date()},
                        "Initial version"
                    }
            case element()
                return
                    element {node-name($node)} {
                        $node/@*,
                        app:parse-template($node/node(), $odd, $title)
                    }
            default
                return
                    $node
};
