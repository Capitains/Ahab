xquery version "3.0"; 
(:
  Copyright 2012-2014 The Alpheios Project, Ltd.
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

(:
  This module implements utility functions for the CTS and CTS-X APIs
:)
module namespace cts-utils = "http://alpheios.net/namespaces/cts-utils";

declare variable $cts-utils:writeableCollection := 'sosol';

(: Get the path to the writeable collection in the repository
   Return Value:
     the collection path as xs:string
:)
declare function cts-utils:getWriteableCollectionPath() as xs:string
{
  fn:concat('/db/repository/', $cts-utils:writeableCollection)
};

(: Get the path at which to read/write a collection defined for the supplied inventory name
   Parameters:
     $a_inv as xs:string the inventory name
   Return Value:
     the inventory collection path as xs:string
:)
declare function cts-utils:getWriteableInventoryCollectionPath(
  $a_inv as xs:string
) as xs:string
{
  fn:concat(cts-utils:getWriteableCollectionPath(), '/', $a_inv)
};

(: Get the filename for the supplied inventory name
   Parameters:
     $a_inv as xs:string the inventory name
   Return Value:
     the inventory filename as xs:string
:)
declare function cts-utils:getWriteableInventoryFilename(
  $a_inv as xs:string
) as xs:string
{
  fn:concat($cts-utils:writeableCollection,'-inventory-',$a_inv,".xml")
};

(: Get the path at which to read/write the supplied inventory name
   Parameters:
     $a_inv as xs:string the inventory name
   Return Value:
     the inventory path as xs:string
:)
declare function cts-utils:getWriteableInventoryPath(
  $a_inv as xs:string
) as xs:string
{
  fn:concat(
    cts-utils:getWriteableInventoryCollectionPath($a_inv),
    '/',
    cts-utils:getWriteableInventoryFilename($a_inv)
  )
};

(: Get the path at which to read/write the supplied text file name
   Parameters:
     $a_inv as xs:string the inventory name
   Return Value:
     the text file path as xs:string
:)
declare function cts-utils:getWriteableTextPath(
  $a_inv as xs:string
) as xs:string
{
  fn:concat(
    cts-utils:getWriteableCollectionPath(),
    '/',
    $a_inv,
    '/',
    $cts-utils:writeableCollection,
    '-text-',
    $a_inv,
    ".xml"
  )
};

