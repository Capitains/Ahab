xquery version "3.0";
(:
  Copyright 2010-2014 The Alpheios Project, Ltd.
  http://alpheios.net

  This file is part of Alpheios.

  Alpheios is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Alpheios is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
:)
module namespace cts-api="http://github.com/Capitains/cts-XQ";

import module namespace mapsutils = "http://github.com/ponteineptique/CTS-API"
       at "./maps-utils.xql";
import module namespace ctsx = "http://alpheios.net/namespaces/cts"
       at "./cts.xql";
import module namespace ctsi = "http://alpheios.net/namespaces/cts-implementation"
       at "./cts-impl.xql";
import module namespace rest="http://exquery.org/ns/restxq";

declare namespace CTS = "http://chs.harvard.edu/xmlns/cts";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

(:~
 : Get all possible request
 :)
declare
    %rest:GET
    %rest:path("/")
    %rest:query-param("request", "{$request}", "")
    %rest:query-param("urn", "{$urn}", "")
    %rest:query-param("inv", "{$inv}", "")
    %rest:query-param("level", "{$level}", "")
    %rest:produces("application/xml", "text/xml")
function cts-api:root($request as xs:string, $inv as xs:string*, $urn as xs:string*, $level as xs:string*) {
  let $startTime := util:system-time()
  let $map := map:new()
  let $reply := cts-api:router($request, $inv, $urn, $level)
  let $cts := map:get($map, "cts")
  let $response :=
    if (fn:node-name($reply) eq xs:QName("CTS:CTSError"))
    then
      $reply
    else
      element { "CTS:" || $e_query }
      {
        namespace tei { "http://www.tei-c.org/ns/1.0" },
        element CTS:request
        {
          attribute elapsed-time { string(seconds-from-duration(util:system-time() - $startTime) * 1000) },
          element CTS:requestName { $e_query },
          element CTS:requestUrn { $e_urn },
          element CTS:psg { xs:string($cts/passage) },
          element CTS:workurn { xs:string($cts/editionUrn) },
          for $gn in $cts/groupname
          return
            element CTS:groupname
            {
              attribute xml:lang { $gn/@xml:lang },
              xs:string($gn)
            },
          for $ti in $cts/title
          return
            element CTS:title
            {
              attribute xml:lang { $ti/@xml:lang },
              xs:string($ti)
            },
          for $la in $cts/label
          return
            element CTS:label
            {
              attribute xml:lang { $la/@xml:lang },
              xs:string($la)
            }
        },
      $reply
      }

  return (
      <rest:response>
      </rest:response>,
      $response)
};

declare 
  function
    cts-api:router($e_query as xs:string, $e_inv as xs:string*, $e_urn as xs:string*, $e_level as xs:string*) as node()* {
        try {
            switch($e_query)
                case "GetCapabilities" 
                    return ctsx:getCapabilities($e_inv, $e_urn)
                case "GetValidReff" 
                    return ctsx:getValidReff($e_inv, $e_urn, $e_level)
                case "GetPassage"
                    return ctsx:getPassage($e_inv, $e_urn)
                case "GetFirstUrn"
                    return ctsx:getFirstUrn($e_inv, $e_urn)
                case "GetPrevNextUrn"
                    return ctsx:getPrevNextUrn($e_inv, $e_urn)
                case "GetLabel"
                    return ctsx:getLabel($e_inv, $e_urn)
                case "GetPassagePlus"
                    return ctsx:getPassagePlus($e_inv, $e_urn)
                default
                    return () (: When the request does not exist :)
        } catch * {
            cts-api:errorLayout($err:description, $err:value, $err:code, $err:line-number, $err:column-number, $err:additional)
        }
  };

declare function cts-api:errorLayout
    ($description, $value, $code, $line-number, $column-number, $additional) {
        
    <CTS:CTSError>
      <message>{ $description }</message>
      <value>{ $value }</value>
      <code>{ $code }</code>
      <position>l {$line-number}, c {$column-number}</position>
      <stack>{$additional}</stack>
    </CTS:CTSError>
};
