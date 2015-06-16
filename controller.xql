xquery version "3.0";

import module namespace cts-api="http://github.com/Capitains/cts-XQ" at "./modules/rest.xql";
import module namespace restxq="http://exist-db.org/xquery/restxq" at "../dashboard/modules/restxq.xql";

declare variable $exist:path external;
declare variable $exist:resource external;
declare variable $exist:controller external;
declare variable $exist:prefix external;
declare variable $exist:root external;

let $functions := util:list-functions("http://github.com/Capitains/cts-XQ")
return
    (: All URL paths are processed by the restxq module :)
    restxq:process($exist:path, $functions)