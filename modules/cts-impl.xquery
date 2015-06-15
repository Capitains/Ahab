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

(: Implementation-dependent routines :)

module namespace ctsi = "http://alpheios.net/namespaces/cts-implementation";
import module namespace transform = "http://exist-db.org/xquery/transform";

declare function ctsi:add-response-header(
  $name as xs:string,
  $value as xs:string
)
{
  response:set-header($name, $value)
};

declare function ctsi:get-request-parameter($name as xs:string)
{
  request:get-parameter($name, ())
};

declare function ctsi:get-request-parameter(
  $name as xs:string,
  $default as xs:string?
)
{
  request:get-parameter($name, $default)
};

declare function ctsi:get-request-body()
{
  request:get-data()
};

declare function ctsi:document-store(
  $collection as xs:string,
  $uri as xs:string,
  $root as node()
)
{
  xmldb:store(
    $collection,
    $uri,
    $root
  )
};

declare function ctsi:http-get(
    $uri as xs:string
)
{
    httpclient:get(
      fn:resolve-uri($uri),
      fn:false(), (: Don't Persist :)
      element()
    ) 
};

(: wrapper for XSLT call :)
declare function ctsi:xslt-transform(
  $a_input as node()?,
  $a_stylesheet as element(),
  $a_params as element(parameters)
)
{
  transform:transform($a_input, $a_stylesheet, $a_params)
};
