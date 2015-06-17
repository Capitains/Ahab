xquery version "3.0";

import module namespace xrest="http://exquery.org/ns/restxq/exist" at "java:org.exist.extensions.exquery.restxq.impl.xquery.exist.ExistRestXqModule";

let $_ := xrest:register-module(xs:anyURI("/db/apps/CTS5XQ/modules/rest.xql"))
return (rest:resource-functions())
    