(:
 : This file is a try for porting MarkLogic and BaseX implementation of maps
 : 
 : Thibault Clérice
 : ponteineptique@github
 :)
xquery version "3.0";

module namespace mapsutils = "http://github.com/ponteineptique/CTS-API";

declare function mapsutils:put($map as map, $key as xs:string, $value as item()) as map {
    let $map := map:new(($map, map:entry($key, $value )))
    return $map
};

declare function mapsutils:merge($map1 as map, $map2 as map) as map {
    let $map := map:new(($map1, $map2))
    return $map
};