xquery version "3.0";

import module namespace xdb="http://exist-db.org/xquery/xmldb";
import module namespace xrest="http://exquery.org/ns/restxq/exist" at "java:org.exist.extensions.exquery.restxq.impl.xquery.exist.ExistRestXqModule";

(: The following external variables are set by the repo:deploy function :)

(: the target collection into which the app is deployed :)
declare variable $target external;

xrest:register-module(xs:anyURI($target || "/modules/rest.xql")),
xmldb:create-collection("/db", "urns-cache")