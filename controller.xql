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

import module namespace mapsutils = "http://github.com/ponteineptique/CTS-API"
       at "modules/maps-utils.xquery";
import module namespace ctsx = "http://alpheios.net/namespaces/cts"
       at "modules/cts.xquery";
import module namespace ctsi = "http://alpheios.net/namespaces/cts-implementation"
       at "modules/cts-impl.xquery";
import module namespace console = "http://exist-db.org/xquery/console";
(:  :import module namespace map = "http://www.w3.org/2005/xpath-functions/map"; :)

declare namespace CTS = "http://chs.harvard.edu/xmlns/cts";
declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare namespace error = "http://marklogic.com/xdmp/error";

let $startTime := util:system-time()
let $map := map:new()
let $_ := ctsi:add-response-header("Access-Control-Allow-Origin", "*")
let $e_query := ctsi:get-request-parameter("request", ())
let $e_urn :=  ctsi:get-request-parameter("urn", ())
let $e_level := xs:int(ctsi:get-request-parameter("level", "1"))
let $e_context := xs:int(ctsi:get-request-parameter("context", "0"))
let $e_uuid := ctsi:get-request-parameter("xuuid", ())
let $e_xinv := ctsi:get-request-body()
let $e_inv := ctsi:get-request-parameter("inv", $ctsx:defaultInventory)
let $query := fn:lower-case($e_query)
let $e_query :=
  if ($query = 'getcapabilities') then "GetCapabilities"
  else if ($query = 'getvalidreff') then "GetValidReff"
  else if ($query = 'getpassage') then "GetPassage"
  else if ($query = 'getpassageplus') then "GetPassagePlus"
  else if ($query = 'getfirsturn') then "GetFirstUrn"
  else if ($query = 'getprevnexturn') then "GetPrevNextUrn"
  else if ($query = 'getlabel') then "GetLabel"
  else $e_query

let $reply :=
try
{
  if ($query = 'getcapabilities')
  then ctsx:getCapabilities($e_inv, $e_urn)
  else if ($query = 'getvalidreff')
  then ctsx:getValidReff($e_inv, $e_urn, $e_level)
  else if ($query = 'getpassage')
  then ctsx:getPassage($e_inv, $e_urn)
  else if ($query = 'getfirsturn')
  then ctsx:getFirstUrn($e_inv, $e_urn) (: GetFirstUrn :)
  else if ($query = 'getprevnexturn')
  then ctsx:getPrevNextUrn($e_inv, $e_urn) (: GetPrevNextUrn :)
  else if ($query = 'getlabel')
  then ctsx:getLabel($e_inv, $e_urn) (: GetLabel :)
  else if ($query = 'getpassageplus')
  then ctsx:getPassagePlus($e_inv, $e_urn)
  else
    fn:error(
      xs:QName("INVALID-REQUEST"),
      "Unsupported request: " || $e_query
    )
} catch * {
  <CTS:CTSError>
    <message>{ $err:description }</message>
    <value>{ $err:value }</value>
    <code>{ $err:code }</code>
    <position>l {$err:line-number}, c {$err:column-number}</position>
    <stack>{$err:additional}</stack>
  </CTS:CTSError>
}

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

return $response