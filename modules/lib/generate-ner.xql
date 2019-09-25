(:
 :  Copyright (C) 2019 Magdalena Turska
 :
 :  This program is free software: you can redistribute it and/or modify
 :  it under the terms of the GNU General Public License as published by
 :  the Free Software Foundation, either version 3 of the License, or
 :  (at your option) any later version.
 :
 :  This program is distributed in the hope that it will be useful,
 :  but WITHOUT ANY WARRANTY; without even the implied warranty of
 :  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 :  GNU General Public License for more details.
 :
 :  You should have received a copy of the GNU General Public License
 :  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 :)
xquery version "3.1";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace tei="http://www.tei-c.org/ns/1.0";

import module namespace config="http://www.tei-c.org/tei-simple/config" at "../config.xqm";
import module namespace pm-config="http://www.tei-c.org/tei-simple/pm-config" at "../pm-config.xql";
import module namespace pages="http://www.tei-c.org/tei-simple/pages" at "pages.xql";
import module namespace tpu="http://www.tei-c.org/tei-publisher/util" at "util.xql";

declare option output:method "html";
declare option output:html-version "5.0";
declare option output:media-type "text/html";

let $col := collection('/db/apps/wall/data')/tei:TEI
let $odd := request:get-parameter("odd", 'ner.odd')
let $output := '/db/apps/tei-publisher/data/temp'


    for $doc in $col
    
    
        let $out := $pm-config:web-transform($doc, map { "root": $doc }, $odd)
        let $text := normalize-space(string-join($out, ' '))
        let $file := util:document-name($doc) || '.txt'
        return
            
                if (doc-available($output || '/' || util:document-name($doc))) then 
                   (
                    xmldb:remove($output, $file),
                    xmldb:store($output, $file, $text)
                   )
                else 
                    xmldb:store($output , $file, $text)


            


