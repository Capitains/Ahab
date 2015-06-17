xquery version "3.0";

module namespace cts-common = "http://github.com/Capitains/CTS5-XQ/commons";

import module namespace xmldb="http://exist-db.org/xquery/xmldb";

declare namespace CTS = "http://chs.harvard.edu/xmlns/cts";
declare namespace ti = "http://chs.harvard.edu/xmlns/cts";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare variable $cts-common:defaultInventory := fn:doc("../conf/conf.xml")//default/text();
declare variable $cts-common:conf := collection(xs:string(fn:doc("../conf/conf.xml")//inventories/@inventoryCollection));
declare variable $cts-common:cache := fn:doc("../conf/conf.xml")//credentials;


declare function cts-common:citationXpath($citation) {
    
    let $first := fn:string($citation/@scope)
    let $last := replace(fn:string($citation/@xpath), "//", "/")
    
    let $scope := fn:concat($first, $last)
    let $xpath := replace($scope,"='\?'",'')
    return $xpath
};

declare function cts-common:fake-match-document(
        $level as xs:integer, (: Level at which we are currently :)
        $citations as element()*, (: List of citations :)
        $body, (: Body/Context to which we should make xpath :)
        $urn as xs:string, (: Urn of the document :)
        $parents as xs:string*, (: Parents N identifier :)
        $remove as xs:string? (: String to remove from xpath as its parent related path :)
    ) {
        let $citation := $citations[1]
        let $xpath := cts-common:citationXpath($citation)
        let $masterPath := 
            if ($remove)
            then replace($xpath, "^("||replace($remove, '(\.|\[|\]|\\|\||\-|\^|\$|\?|\*|\+|\{|\}|\(|\))','\\$1')||")", "")
            else $xpath
        let $masters := util:eval("$body/" || $masterPath, true())
        let $next := subsequence($citations, 2)
        let $nextLevel := $level + 1
    
    return 
            for $master in $masters 
             let $childs := 
                if( count($next) = 0)
                then
                    ()
                else
                    cts-common:fake-match-document($nextLevel, $next, $master, $urn, ($parents, string($master/@n)), $xpath)
                    
             return (
              element urn {
                 attribute level { $level },
                 $urn || ":" || string-join(($parents, string($master/@n)), ".")
              },
              $childs
             )
};

(: for backwards compatibility default to alpheios inventory :)
declare function cts-common:parseUrn($a_urn as xs:string)
{
  cts-common:parseUrn($cts-common:defaultInventory, $a_urn)
};
(:
    function to parse a CTS Urn down to its individual parts
    Parameters:
        $a_urn: the CTS URN (e.g. urn:cts:greekLit:tlg012.tlg002.alpheios-text-grc1)
    Return value:
        A) if $a_urn is a valid cts urn: an element adhering to the following
        <ctsUrn>
            <namespace></namespace>
            <groupname></groupname>
            <title></title>
            <label></label>
            <workUrn></workUrn>
            <textgroup></textgroup>
            <work></work>
            <version></version>
            <passageParts>
                <rangePart>
                    <part></part>
                    <part><part>
                </rangePart>
                <rangePart>
                    <part></part>
                    <part><part>
                </rangePart>
            </passageParts>
            <subref position="">
            </subref>
            <fileInfo>
                <basePath></basePath>
                <alpheiosEditionId></alpheiosEditionId>
                <alpheiosDoctype></alpheiosDocType>
            </fileInfo>
        <ctsUrn>
        B) Or if $a_urn is a text string as identified by the prefix 'alpheiosusertext:<lang>' then
        returns a <dummy><usertext lang="<lang>">Text String</usertext></dummy>
        TODO this latter option is a bit of hack, should look at a better way to handle this
        but since most requests go through parseUrn, this was the easiest place for now
:)
declare function cts-common:parseUrn($a_inv as xs:string, $a_urn as xs:string)
{
  if (fn:matches($a_urn, '^alpheiosusertext:'))
  then
    let $parts := fn:tokenize($a_urn,':')
    let $lang := $parts[2]
    let $text := fn:string-join(fn:subsequence($parts, 3), ' ')
    return
      <dummy>
        <usertext lang="{$lang}">{$text}</usertext>
      </dummy>
  else
    let $components := fn:tokenize($a_urn, ":")
    let $namespace := $components[3]
    let $workComponents := fn:tokenize($components[4], "\.")
    (: TODO do we need to handle the possibility of a work without a text group? :)
    let $textgroup := $workComponents[1]
    let $work := $workComponents[2]

    let $passage := $components[5]
    let $passageComponents := fn:tokenize($components[5], "-")
    let $part1 := $passageComponents[1]
    let $part2 := $passageComponents[2]
    let $part2 := if (fn:empty($part2)) then $part1 else $part2

    let $namespaceUrn := fn:string-join($components[1,2,3], ":")
    let $groupUrn := $namespaceUrn || ":" || $textgroup
    let $workUrn := $groupUrn || "." || $work
    let $cat := cts-common:getCapabilities($a_inv, $namespaceUrn, $groupUrn, $workUrn)
    let $catwork :=
      $cat//ti:textgroup[@urn eq $groupUrn]/ti:work[@urn eq $workUrn]
    let $version :=
      (: if version specified, use it :)
      if (fn:count($workComponents) > 2)
      then
        $workComponents[fn:last()]
      (: otherwise use default for the work :)
      else
        fn:substring-after(
          $catwork/(ti:edition|ti:translation)[@default]/@urn,
          ":"
        )
    let $versionUrn := $workUrn || "." || $version
    let $catversion := $catwork/(ti:edition|ti:translation)[@urn eq $versionUrn]

    return
      element ctsURN
      {
        element urn { $a_urn },
        (: urn without any passage specifics:)
        element groupUrn { $groupUrn },
        element versionUrn { $versionUrn },
        element versionLang { $catversion/@xml:lang },
        element workUrn { $workUrn },
        element workLang { $catwork/@xml:lang },
        element namespace{ $namespace },
        (: TODO is it possible for components of the work id to be in different namespaces?? :)
        for $gn in $cat//ti:textgroup[@urn eq $groupUrn]
                        /ti:groupname
        return
          element groupname
          {
            $gn/@xml:lang,
            xs:string($gn)
          },
        for $ti in $catwork/ti:title
        return
          element title
          {
            attribute xml:lang { $ti/@xml:lang},
            xs:string($ti)
          },
        for $lab in $catversion/ti:label
        return
          element label
          {
            attribute xml:lang { $lab/@xml:lang},
            xs:string($lab)
          },
        element passage { $passage },
        element passageParts
        {
          cts-common:_parseRangePart($part1),
          cts-common:_parseRangePart($part2)
        },
        element fileInfo
        {
          if (fn:starts-with($version, 'alpheios-'))
          then
            (: TODO look up the path in the TextInventory :)
            let $parts := fn:tokenize($version,'-')
            return
            (
              element basePath
              {
                "/db/repository/" ||
                $namespace ||
                "/" ||
                fn:string-join(
                  fn:subsequence($workComponents, 1, fn:count($workComponents) - 1),
                  "/"
                )
              },
              element fullPath
              {
                if (fn:exists($catversion))
                then
                  $catversion/ti:online/@docname/fn:string()
                else
                  "/db/repository/" ||
                  $namespace ||
                  "/" ||
                  fn:string-join($workComponents, "/") ||
                  $version ||
                  ".xml"
              },
              element alpheiosDocType { $parts[2] },
              for $i in fn:subsequence($parts, 3)
              return element alpheiosEditionId { $i }
            )
          else if (fn:not($version))
          then
            element basePath
            {
              "/db/repository/" ||
              $namespace ||
              "/" ||
              fn:string-join($workComponents, "/")
            }
          else if ($catversion)
          then
            element fullPath { $catversion/ti:online/@docname/fn:string() }
          else()
        }
      }
};

declare function cts-common:_parseRangePart($part1)
{
  if (fn:empty($part1)) then () else

  let $subparts := fn:tokenize($part1, "@")
  let $subref := $subparts[2]
  return
    element rangePart
    {
      for $p in fn:tokenize($subparts[1], "\.")
      return element part { $p },

      if (fn:exists($subref))
      then
        if (fn:matches($subref, ".*\[.*\]"))
        then
          let $string := fn:substring-before($subref, "[")
          let $pos := fn:substring-before(fn:substring-after($subref, "["), "]")
          let $pos :=
            if ($pos castable as xs:positiveInteger)
            then
              xs:positiveInteger($pos)
            else
              fn:error(
                xs:QName("BAD-SUBREF"),
                "Subref index not a positive integer: " || $pos
              )
          return element subRef { attribute position { $pos }, $string }
        else
          element subRef { attribute position { 1 }, $subref }
      else ()
    }
};

declare function cts-common:simpleUrnParser($a_urn)
{
    let $components := fn:tokenize($a_urn, ":")
    let $namespace := $components[3]
    let $workComponents := fn:tokenize($components[4], "\.")
    (: TODO do we need to handle the possibility of a work without a text group? :)
    let $textgroup := $workComponents[1]
    let $work := $workComponents[2]

    let $passage := $components[5]
    let $passageComponents := fn:tokenize($components[5], "-")
    let $part1 := $passageComponents[1]
    let $part2 := $passageComponents[2]
    let $part2 := if (fn:empty($part2)) then $part1 else $part2

    let $namespaceUrn := fn:string-join($components[1,2,3], ":")
    let $groupUrn := if (fn:exists($textgroup)) then $namespaceUrn || ":" || $textgroup else ()
    let $workUrn := if(fn:exists($work)) then $groupUrn || "." || $work else ()
    
    
    return
      element ctsURN
      {
        element urn { $a_urn },
        (: urn without any passage specifics:)
        element groupUrn { $groupUrn },
        element workUrn { $workUrn },
        element namespace{ $namespaceUrn }
      }
};

declare function cts-common:text-empty($node) {
    if (fn:empty($node/text()))
    then ()
    else $node
};


(:
  CTS getValidUrns request
  Parameters:
    $a_inv the inventory name
    $a_urn the passage urn
    $a_level citation level
  Returns
    the list of valid urns

  Note: This code depends on the format of xpath attributes being
    /<element>[@<attribute>='?']
  That is, steps in the path are defined by specified elements containing
  specified attributes.
  Removing "='?'" yields the steps needed for enumerating all elements at a given level.
  Substituting a specific value for '?' yields a step for mapping URN passage components
  to elements.
:)
declare function cts-common:getValidUrns(
  $a_inv as xs:string,
  $a_urn as xs:string,
  $a_level as xs:int
) as element(CTS:urn)*
{
    cts-common:getValidUrns($a_inv, $a_urn, $a_level, true())
};

declare function cts-common:getValidUrns(
  $a_inv as xs:string,
  $a_urn as xs:string,
  $a_level as xs:int,
  $remodel as xs:boolean
) as element(CTS:urn)*
{
  let $cts := cts-common:parseUrn($a_inv, $a_urn)
  let $startVals := $cts/passageParts/rangePart[1]/part[1 to $a_level]/fn:string()
  let $endVals := $cts/passageParts/rangePart[2]/part[1 to $a_level]/fn:string()

  let $entry := cts-common:getCatalogEntry($cts, $a_inv)
  let $cites := $entry/ti:online//ti:citation
  let $citations := subsequence($cites, 1, $a_level)
  let $doc := fn:doc($cts/fileInfo/fullPath)
  let $urns := cts-common:use-fake-document-cache(
        1, (: Level at which we are currently :)
        $cites, (: List of citations :)
        $doc, (: Body/Context to which we should make xpath :)
        xs:string($cts//versionUrn/text()), (: Urn of the document :)
        (), (: Parents N identifier :)
        () (: String to remove from xpath as its parent related path :)
    )
  
  return 
      if ($remodel)
      then
          for $urn in $urns[@level = $a_level]
            return element CTS:urn {
                $urn/@urn,
                $urn/text()
            }
      else
          $urns[@level = $a_level]
};


declare function cts-common:use-fake-document-cache(
    $level as xs:integer, (: Level at which we are currently :)
    $citations as element()*, (: List of citations :)
    $body, (: Body/Context to which we should make xpath :)
    $urn as xs:string, (: Urn of the document :)
    $parents as xs:string*, (: Parents N identifier :)
    $remove as xs:string? (: String to remove from xpath as its parent related path :)
) {
    
    (: this logs you in; you can also get these variables from your session variables :)
    let $safeUrn := replace($urn, ":", "_")
    let $collection := '/db/urns-cache/' || $safeUrn
    (: replace this with a unique file name with a sequence number :)
    let $docHash := util:hash($body, "md5")
    let $filename :=  $docHash || ".xml" 
    let $doc := try {
        doc($collection || "/" || $filename)//urn
    } catch * {
        ()
    }
    return
        if ($doc)
        then $doc
        else
            let $response := cts-common:fake-match-document(
                                $level,
                                $citations,
                                $body,
                                $urn,
                                $parents,
                                $remove
                            )
            let $store-return-status := (
                    xmldb:login('/db/urns-cache', $cts-common:cache/user/text(), $cts-common:cache/password/text()),
                    xmldb:create-collection('/db/urns-cache/', $safeUrn),
                    xmldb:store($collection, $filename, element reff { $response } )
                )
            return $response
};


(: 
 : Merge Urns takes a tuple of urn and transform it into one urn
 : Nullable
 :)
declare function cts-common:mergeUrns($reff) {
  if (count($reff) = 0)
  then
      ()
  else
      if ($reff[1] = $reff[2])
      then
          $reff[1]
      else
          let $e := tokenize($reff[2], ":")[5]
          return $reff[1] || "-"  || $e
};
(:
    replace bind variables in the template xpath from the TextInventory with the requested values
    Parameters
        $a_startParts the passage parts identifiers of the start of the range
        $a_endParts the passage part identifiers of the end of the range
        $a_scope the base scope of the range
        $a_paths the template xpaths containing the bind variables
    Return Value
        the full path with the bind variables replaced
:)
declare function cts-common:replaceBindVariables(
  $a_startParts,
  $a_endParts,
  $a_scope,
  $a_paths
) as xs:string
{
  $a_scope ||
  fn:string-join(
    for $path at $i in $a_paths
    return cts-common:_rbv($a_startParts[$i], $a_endParts[$i], $path),
    ""
  )
};

declare function cts-common:_rbv(
  $a_start,
  $a_end,
  $a_path
) as xs:string
{
  if (fn:exists($a_start))
  then
    if (fn:exists($a_end))
    then
      let $startRange :=
        if ($a_start/text())
        then
          ' = "' || $a_start || '"'
        else ""
      let $endRange :=
        if ($a_end/text())
        then
          ' = "' || $a_end || '"'
        else ""
      return
        fn:replace(
          $a_path,
          "^(.*?)(@[\w\d\._:\s]+)=[""']\?[""'](.*)$",
          fn:concat("$1", "$2", $startRange, " and ", "$2", $endRange, "$3")
        )
    else
      if ($a_start/text())
      then
        fn:replace(
          $a_path,
          "^(.*?)\?(.*)$",
          fn:concat("$1", $a_start, "$2")
        )
      else
        fn:replace(
          $a_path,
          "^(.*?)(@[\w\d\._:\s]+)=[""']\?[""'](.*)$",
          fn:concat("$1", "$2", "$3")
        )
  else
    $a_path
};

(:
    replace bind variables in the template xpath from the TextInventory with the requested values
    Parameters
        $a_passageParts the passage parts identifiers
        $a_scope the base scope of the range
        $a_paths the template xpaths containing the bind variables
    Return Value
        the full path with the bind variables replaced
:)
declare function cts-common:replaceBindVariables(
  $a_passageParts,
  $a_scope,
  $a_paths
) as xs:string
{
  $a_scope ||
  fn:string-join(
    for $path at $i in $a_paths
    return cts-common:_rbv($a_passageParts[$i], $path),
    ""
  )
};

declare function cts-common:_rbv
(
  $a_part, 
  $a_path
) as xs:string
{
  if (fn:empty($a_part)) then $a_path else

  if ($a_part/text())
  then
    fn:replace(
      $a_path,
      "^(.*?)\?(.*)$",
      fn:concat("$1", $a_part, "$2")
    )
  else
    fn:replace(
      $a_path,
      "^(.*?)(@[\w\d\._:\s]+)=[""']\?[""'](.*)$",
      fn:concat("$1", "$2", "$3")
    )
};

(:
    get a catalog entry for a version
    Parameters:
      $a_cts - parsed URN
    Return Value
      the catalog entry for the requested version
:)
declare function cts-common:getCatalogEntry($a_cts, $a_inv) as node()*
{
  let $version :=
    $cts-common:conf//ti:TextInventory[@tiid=$a_inv]//(ti:edition|ti:translation)
      [@workUrn eq $a_cts/workUrn]
      [@urn eq $a_cts/versionUrn]

  let $_ :=
    if (fn:empty($version))
    then fn:error(xs:QName("BAD-URN"), "Version not found: " || $a_cts/versionUrn)
    else ()

  return $version
};

(:
  cts-common:_extractPassage - recursive function to extract passage
    $a_base - base node
    $a_path1 - starting path of subpassage to extract
    $a_path2 - ending path of subpassage to extract

  If $a_path1 is null then all nodes up to the node
  specified by $a_path2 should be extracted.
  If $a_path2 is null then all nodes after the node
  specified by $a_path1 should be extracted.
:)
declare function cts-common:_extractPassage(
  $a_base as node(),
  $a_path1 as xs:string*,
  $a_path2 as xs:string*
) as node()*
{
  (: if no paths, return all subnodes :)
  if (fn:empty($a_path1) and fn:empty($a_path2)) 
  then 
      $a_base/node() 
  else if (not(fn:head($a_path1)) and not(fn:head($a_path2)))
  (: "and" because if they are both missing, it means we have a //:)
  then 
      let $step1 := fn:head(fn:tail($a_path1))
      let $step2 := fn:head(fn:tail($a_path2))
      
      let $n1 := 
        for $n in util:eval("$a_base/descendant::node()[count(./descendant::" || $step1 || ") = 1]", false()) 
            return 
                "*:" ||
                local-name($n) || 
                "[count(.//" ||
                $step1 ||
                ") = 1]"
                
      let $n2 := 
        for $n in util:eval("$a_base/descendant::node()[count(./descendant::" || $step2 || ") = 1]", false())
            return 
                "*:" ||
                local-name($n) ||
                "[count(.//" || 
                $step2 || 
                ") = 1]"
        
      return
        cts-common:_extractPassage(
            $a_base,
            ($n1, fn:tail($a_path1)),
            ($n2, fn:tail($a_path2))
        )
  else
  
  (: evaluate next steps in paths :)
  let $step1 := fn:head($a_path1)
  let $step2 := fn:head($a_path2)
    
  let $n1 :=
    if (fn:exists($a_path1) and fn:exists($step1))
    then util:eval("$a_base/" || $step1, true())
    else ()
  let $n2 :=
    if (fn:exists($a_path2) and fn:exists($step2))
    then util:eval("$a_base/" || $step2, true())
    else ()

  return
    (: if steps are identical :)
    if ($n1 is $n2)
    then
      (: build subnode and recurse :)
      element { "tei:" || fn:node-name($n1) }
      {
        $n1/@*,
        cts-common:_extractPassage($n1, fn:tail($a_path1), fn:tail($a_path2))
      }
    (: if everything from node to end :)
    else if (fn:exists($n1) and fn:empty($step2))
    then
    (
      element { "tei:" || fn:node-name($n1) }
      {
        $n1/@*,
        cts-common:_extractPassage($n1, fn:tail($a_path1), ())
      },
      $a_base/node()[$n1 << .]
    )
    (: if everything from start to node :)
    else if (fn:exists($n2) and fn:empty($step1))
    then
    (
      (: MarkLogic seems to evaluate ">> $n2" much faster than "<< $n2" :)
      $a_base/node()[fn:not(. >> $n2) and fn:not(. is $n2)],
      element { "tei:" || fn:node-name($n2) }
      {
        $n2/@*,
        cts-common:_extractPassage($n2, (), fn:tail($a_path2))
      }
    )
    (: if steps diverge :)
    else if (fn:exists($n1) and fn:exists($n2))
    then
    (
      (: take all children of start from subnode on :) 
      element { "tei:" || fn:node-name($n1) }
      {
        $n1/@*,
        cts-common:_extractPassage($n1, fn:tail($a_path1), ())
      },
      (: take everything in between the nodes :)
      $a_base/node()[($n1 << .) and fn:not(. >> $n2) and fn:not(. is $n2)],
      (: take all children of end up to subnode :)
      element { "tei:" || fn:node-name($n2) }
      {
        $n2/@*,
        cts-common:_extractPassage($n2, (), fn:tail($a_path2))
      }
    )
    (: bad step - return nothing :)
    else ()
};

declare function cts-common:preparePassage($a_inv, $a_urn) {
  let $cts := cts-common:parseUrn($a_inv,$a_urn)
  let $doc := fn:doc($cts/fileInfo/fullPath)
  let $level1 := fn:count($cts/passageParts/rangePart[1]/part)
  let $level2 := fn:count($cts/passageParts/rangePart[2]/part)

  (: range endpoints must have same depth :)
  let $_ :=
    if ($level1 ne $level2)
    then
      fn:error(xs:QName("BAD-RANGE"), "Endpoints of range have different depths: " || $a_urn)
    else ()

  let $entry := cts-common:getCatalogEntry($cts, $a_inv)
  let $cites := $entry/ti:online//ti:citation

  (: subrefs must be in leaf citation nodes :)
  let $_ :=
    for $part in $cts/passageParts/rangePart
    where fn:exists($part/subRef) and
          (fn:count($part/part) ne fn:count($cites))
    return
      fn:error(xs:QName("BAD-RANGE"), "Subref must be in leaf citation node: " || $a_urn)

  (: find passage paths in doc :)
  let $xpath1 :=
    cts-common:replaceBindVariables(
      $cts/passageParts/rangePart[1]/part,
      $cites[1]/@scope,
      fn:subsequence($cites, 1, $level1)/@xpath
    )
  let $xpath2 :=
    cts-common:replaceBindVariables(
      $cts/passageParts/rangePart[2]/part,
      $cites[1]/@scope,
      fn:subsequence($cites, 1, $level2)/@xpath
    )

  let $n1 := try { util:eval("$doc" || $xpath1, true()) } catch * {
    fn:error(
      xs:QName("INVALID-CITATION-Information"),
      "Unsupported Xpath: " || $xpath1
    )
  }
  let $n2 := try { util:eval("$doc" || $xpath2, true()) } catch * {
    fn:error(
      xs:QName("INVALID-CITATION-Information"),
      "Unsupported Xpath: " || $xpath2
    )
  }

  (: end node must not precede start node :)
  let $_ :=
    if ($n2 << $n1)
    then fn:error(xs:QName("BAD-RANGE"), "Endpoints out of order: " || $a_urn)
    else ()
  
  return ($doc, $xpath1, $xpath2, $cts, $entry, $cites)
};

declare function cts-common:_extractPassageLoop($passage) {
    cts-common:_extractPassage(
      $passage[1],
      fn:tail(fn:tokenize($passage[2], "/")),
      fn:tail(fn:tokenize($passage[3], "/"))
    )
};

declare function cts-common:prevNextUrns(
    $cts as element()*, (: CTS from prepare passage for example :)
    $amount as xs:integer, (: Number of nodes to select (overrides urns differences), if amout is 0 it is computed according to urns diff or 0 :)
    $reffs as element()* (: Sequence of urn elements :)
) {

    let $parts1 := $cts/passageParts/rangePart[1]/part
    let $startUrn := $cts/versionUrn || ":" || fn:string-join($parts1/text(), ".")
    let $endUrn := 
        if (count($cts/passageParts/rangePart[2]/part) = count($parts1))
        then 
          let $endUrn := $cts/versionUrn || ":" || fn:string-join($cts/passageParts/rangePart[2]/part, ".")
          return $reffs[./text() = $endUrn]
        else ()
    
    let $startReff  := $reffs[./text() = $startUrn]
    let $startIndex := index-of($reffs, $startReff)
    
    (: We get the index of the endUrn :)
    let $endIndex :=
      if ($endUrn)
      then
          index-of($reffs, $endUrn)
      else
          $endUrn
        
    (: We compute the context we want :)
    let $refCount := 
        if($amount = 0)
        then 
            if ($endUrn)
            then $endIndex - $startIndex + 1
            else 1
        else
            1
    
    let $prevMinusRef := 
        if ($startIndex - $refCount <= 1)
        then
            1
        else
            $startIndex - $refCount
            
    let $countUrns := count($reffs)
    let $nextEndRef := 
        if ($endIndex + $refCount >= $countUrns)
        then
            $countUrns
        else
            $endIndex + $refCount
            
    let $prevFirstUrn :=
        if ($prevMinusRef <= 1 and $startIndex = 1)
        then
            ()
        else
            let $s := $reffs[$prevMinusRef]/text()
            let $e :=
                if($prevMinusRef + $refCount >= $startIndex)
                then
                    $reffs[$startIndex - 1]/text()
                else
                    $reffs[$prevMinusRef + $refCount]/text()
                    
            return ($s, $e)
            
    let $nextFirstUrn :=
        if ($endIndex >= $countUrns)
        then
            ()
        else
            let $s := $reffs[$endIndex + 1]/text()
            let $e := $reffs[$nextEndRef]/text()
                    
            return ($s, $e)
    return (
        element CTS:prev {
            element CTS:urn { cts-common:mergeUrns($prevFirstUrn) }
        },
        element CTS:next {
            element CTS:urn { cts-common:mergeUrns($nextFirstUrn) }
        }
    )
};

declare function cts-common:extractPassage($a_inv, $a_urn)
{
  let $passage := cts-common:preparePassage($a_inv, $a_urn)
  return
    (: extract full passage :)
    cts-common:_extractPassageLoop($passage)
};

declare function cts-common:labelLoop(
    $a_node as element()
) {
    if($a_node/local-name() = ("edition", "translation"))
    then 
        (
            cts-common:labelLoop($a_node/ancestor::ti:work),
            for $desc in $a_node/ti:description
                return element ti:version {
                    $desc/@*,
                    $desc/text()
                }
            ,
            element ti:citation {
                string-join($a_node//ti:citation/@label, ", ")
            }
        )
    else if($a_node/local-name() = "work")
    then 
        (
            cts-common:labelLoop($a_node/ancestor::ti:textgroup),
            for $title in $a_node/ti:title
                return element ti:title {
                    $title/@*,
                    $title/text()
                },
            element ti:work {
                xs:string($a_node/@urn)
            }
        )
    else  if($a_node/local-name() = "textgroup")
    then 
        (
            for $title in $a_node/ti:groupname
                return element ti:groupname {
                    $title/@*,
                    $title/text()
                }
        )
    else ()
};

declare function cts-common:getCapabilities($a_inv, $a_namespaceUrn, $a_groupUrn, $a_workUrn) as node() {
  let $ti := ($cts-common:conf//ti:TextInventory[@tiid = $a_inv])[1]
  
  let $groups :=
    (: specified work :)
    if (fn:exists($a_groupUrn))
    then $ti/ti:textgroup[@urn = $a_groupUrn]
    else if (fn:exists($a_namespaceUrn))
    then $ti/ti:textgroup[starts-with(@urn, $a_namespaceUrn)]
    else $ti/ti:textgroup

  let $groupUrns := fn:distinct-values($groups/@urn)
  let $works :=
    (: specified work :)
    if (fn:exists($a_workUrn))
    then $ti//ti:work[@groupUrn = $groupUrns][@urn = $a_workUrn]
    (: all works in inventory :)
    else $ti//ti:work[@groupUrn = $groupUrns]

  return
    element CTS:reply
    {
      element ti:TextInventory
      {
        (:
        attribute {concat('xmlns:', "ti")} { "http://chs.harvard.edu/xmlns/cts3/ti" },
        attribute {concat('xmlns:', "dc")} { "http://purl.org/dc/elements/1.1/" },
        attribute tiversion { "5.0.rc.1" },
        :)
        $ti/@*,
        for $group in $groups
        let $groupWorks := $works[@groupUrn eq $group/@urn]
        where fn:count($groupWorks) gt 0
        order by $group/@urn
        return
          element ti:textgroup
          {
            $group/@urn,
            $group/ti:groupname,
            for $work in $groupWorks
            order by $work/@urn
            return
              element ti:work
              {
                $work/(@urn,@xml:lang),
                $work/*,
                for $version in
                  /(ti:edition|ti:translation)[@workUrn eq $work/@urn]
                order by $version/@urn
                return
                  element { fn:node-name($version) }
                  {
                    $version/@urn,
                    $version/*
                  }
              }
          }
      }
    }
  }  ;