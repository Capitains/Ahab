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

(: Beginnings of the CTS Repository Interface Implementation :)
(: TODO LIST
            support ranges subreferences
            namespacing on cts responses
            getPassage
            getValidReff
            typecheck the function parameters and return values
            make getNextPrev recursive so that it can point to first/last in next/previous book, etc.
:)

module namespace ctsx = "http://alpheios.net/namespaces/cts";

import module namespace cts-common = "http://github.com/Capitains/CTS5-XQ/commons" at "./cts-common.xql";
import module namespace xmldb="http://exist-db.org/xquery/xmldb";

declare namespace CTS = "http://chs.harvard.edu/xmlns/cts";
declare namespace ti = "http://chs.harvard.edu/xmlns/cts";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare variable $ctsx:defaultInventory := fn:doc("../conf/conf.xml")//default/text();
declare variable $ctsx:conf := collection(xs:string(fn:doc("../conf/conf.xml")//inventories/@inventoryCollection));
declare variable $ctsx:cache := fn:doc("../conf/conf.xml")//credentials;

(:
    get a passage from a text
    Parameters:
        $a_inv the inventory name
        $a_urn the passage urn
    Return Value:
        getPassage reply
:)
declare function ctsx:getPassage(
  $a_inv as xs:string,
  $a_urn as xs:string
) as element(CTS:reply)
{
  element CTS:reply
  {
    element CTS:urn { $a_urn },
    element CTS:passage {
        cts-common:extractPassage($a_inv, $a_urn)
    }
  }
};
(:
    CTS getCapabilities request
    Parameters:
        $a_inv - the inventory name
        $a_urn - A urn
    Return Value
        the requested catalog entries

    If group and work ids are supplied, only that work will be returned
    otherwise all works in the inventory will be returned
:)
declare function ctsx:getCapabilities($a_inv, $a_urn)
{
  (: get all works in inventory :)
  if (fn:exists($a_urn))
  then
      let $parsed_urn := cts-common:simpleUrnParser($a_urn)
      return ctsx:getCapabilities($a_inv, cts-common:text-empty($parsed_urn/namespace), cts-common:text-empty($parsed_urn/groupUrn), cts-common:text-empty($parsed_urn/workUrn))
  else
    ctsx:getCapabilities($a_inv, (), (), ())
};
declare function ctsx:getCapabilities($a_inv, $a_namespaceUrn, $a_groupUrn, $a_workUrn)
{
   cts-common:getCapabilities($a_inv, $a_namespaceUrn, $a_groupUrn, $a_workUrn)
};

(:
    CTS getValidReff request (with or without specified level)
    Parameters:
        $a_inv the inventory name
        $a_urn the passage urn
        $a_level citation level
    Returns
        the list of valid urns
:)
declare function ctsx:getValidReff($a_inv, $a_urn) as element(CTS:reply)
{
    ctsx:getValidReff(
      $a_inv,
      $a_urn,
      1
    )
};

declare function ctsx:getValidReff(
  $a_inv as xs:string,
  $a_urn as xs:string,
  $a_level as xs:int
) as element(CTS:reply)
{
  let $cts := cts-common:parseUrn($a_inv, $a_urn)
  let $entry := cts-common:getCatalogEntry($cts, $a_inv)
  
  let $nparts := fn:count($cts/passageParts/rangePart[1]/part)
  let $level := 
    if ($nparts > 0)
    then 
        $nparts + 1
    else
      if($a_level > 0)
      then $a_level
      else
        fn:count($entry/ti:online//ti:citation)
  
  let $reffs := cts-common:getValidUrns($a_inv, $cts/versionUrn/text(), $level)
  return
  element CTS:reply
  {
    element CTS:reff { 
        attribute level { $level },
        if (count(tokenize($a_urn, ":")) > 4)
        then
            $reffs[starts-with(./text(), $cts/urn/text()||".")]
        else
            $reffs
    }
  }
};

(:
    CTS getPassagePlus request, returns the requested passage plus previous/next references
    Parameters:
        $a_inv the inventory name
        $a_urn the passage urn
    Return Value:
        <reply>
            <TEI>
               [ passage elements ]
            </TEI>
        </reply>
        <prevnext>
            <prev>[previous urn]</prev>
            <next>[next urn]</next>
        </prevnext>
:)
declare function ctsx:getPassagePlus($a_inv as xs:string,$a_urn as xs:string)
{
  ctsx:getPassagePlus($a_inv, $a_urn, fn:false())
};

(:
    CTS getPassagePlus request, returns the requested passage plus previous/next references
    Parameters:
        $a_inv the inventory name
        $a_urn the passage urn
        $a_withSiblings - alpheios extension to get sibling unciteable elements for passages (for display - e.g. speaker)
    Return Value:
        <reply>
            <TEI>
               [ passage elements ]
            </TEI>
        </reply>
        <prevnext>
            <prev>[previous urn]</prev>
            <next>[next urn]</next>
        </prevnext>
:)
declare function ctsx:getPassagePlus(
  $a_inv as xs:string,
  $a_urn as xs:string,
  $a_withSiblings as xs:boolean*
)
{
    let $passageInfos := cts-common:preparePassage($a_inv, $a_urn)
    let $doc := $passageInfos[1]
    let $xpath1 := $passageInfos[2]
    let $xpath2 := $passageInfos[3]
    let $cts := $passageInfos[4]
    let $entry := $passageInfos[4]
    let $cite := $passageInfos[4]
    
    let $level := fn:count($cts/passageParts/rangePart[1]/part)
    
    let $passageFull := <container>{cts-common:_extractPassageLoop($passageInfos)}</container>
    let $passage := $passageFull//*:body
    
    let $count := count($cts/passageParts/rangePart[1]/part)
    let $reffs := cts-common:getValidUrns($a_inv, $cts/versionUrn, $count, false())
    
    let $urns := cts-common:prevNextUrns($cts, 0, $reffs)
  
  return
    element CTS:reply {
      element CTS:urn { $a_urn },
      element CTS:label {
        namespace ti { "http://chs.harvard.edu/xmlns/cts" },
        ctsx:getLabel($a_inv, $a_urn)/child::element()
      },
      element CTS:passage {
        $passage
      },
      element CTS:prevnext
      {
        $urns
      }
    }
};

declare function ctsx:getPrevNextUrn(
    $a_inv as xs:string*,
    $a_urn as xs:string
) {

  let $inv :=
    if ($a_inv)
    then $a_inv
    else $ctsx:defaultInventory
    

  let $cts := cts-common:parseUrn($inv, $a_urn)
  let $nparts := fn:count($cts//ti:citation)
  
  let $reffs := cts-common:getValidUrns($inv, $cts/versionUrn/text(), $nparts, false()) 
  let $urns  := cts-common:prevNextUrns($cts, 0, $reffs)
  
  return element CTS:reply
  {
    element CTS:prevnext {
        $urns
    }
  }
};

declare function ctsx:getLabel(
    $a_inv as xs:string*,
    $a_urn as xs:string
) {

  let $inv :=
    if ($a_inv)
    then $a_inv
    else $ctsx:defaultInventory
    
  let $urn := string-join(subsequence(tokenize($a_urn, ":"), 1, 4), ":")
    
  let $inventoryRecord := $ctsx:conf//ti:TextInventory[@tiid=$inv]//(ti:edition|ti:translation)
      [@urn eq $urn]
  
  return element CTS:reply
  {
    namespace ti { "http://chs.harvard.edu/xmlns/cts" },
    element CTS:label {
        cts-common:labelLoop($inventoryRecord)
    }
  }
};

declare function ctsx:getFirstUrn(
    $a_inv as xs:string*,
    $a_urn as xs:string
) {

  let $inv :=
    if ($a_inv)
    then $a_inv
    else $ctsx:defaultInventory
    
  let $cts := cts-common:parseUrn($inv, $a_urn)
  let $nparts := fn:count($cts/passageParts/rangePart[1]/part)
  let $reffs := cts-common:getValidUrns($inv, $cts/versionUrn/text(), $nparts + 1, false()) 
  let $startWith :=
    if ($nparts = 0)
    then $cts/urn/text() || ":"
    else $cts/urn/text() || "."
    
  return element CTS:reply
  {
    element CTS:urn {
        $reffs[contains(./text(), $startWith)][1]/text()
    }
  }
};

declare function ctsx:getFirstPassagePlus(
    $a_inv as xs:string*,
    $a_urn as xs:string
) {

  let $inv :=
    if ($a_inv)
    then $a_inv
    else $ctsx:defaultInventory
    
  let $cts := cts-common:parseUrn($inv, $a_urn)
  let $nparts := fn:count($cts//ti:citation)
  let $reffs := cts-common:getValidUrns($inv, $cts/versionUrn/text(), $nparts, false()) 
    
  let $newURN := $reffs[1]/text()
  
  return ctsx:getPassagePlus($a_inv, $newURN)
};