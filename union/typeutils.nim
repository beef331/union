#
#                    Anonymous unions in Nim
#                   Copyright (c) 2021 Leorize
#
# Licensed under the terms of the MIT license which can be found in
# the file "license.txt" included with this distribution. Alternatively,
# the full text can be found at: https://spdx.org/licenses/MIT.html

## Additional tools for introspecting Nim types

import std/macros

import astutils

const
  Skippable* = {ntyAlias, ntyTypeDesc}
    ## Type kinds that can be skipped by getTypeSkip
  SkippableInst* = {ntyTypeDesc}
    ## Type kinds that can be skipped by getTypeSkipInst

proc getTypeSkip*(n: NimNode, skip = Skippable): NimNode =
  ## Obtain the type of `n`, while skipping through type kinds matching `skip`.
  ##
  ## See `Skippable` for supported type kinds.
  assert skip <= Skippable, "`skip` contains unsupported type kinds: " & $(skip - Skippable)
  result = getType(n).applyLineInfo(n)
  if result.typeKind in skip:
    case result.typeKind
    of ntyAlias:
      result = getTypeSkip(result, skip)
    of ntyTypeDesc:
      result = getTypeSkip(result[1], skip)
    else:
      discard "return as is"

proc getTypeInstSkip*(n: NimNode, skip = SkippableInst): NimNode =
  ## Obtain the type instantiation of `n`, while skipping through type kinds matching `skip`.
  ##
  ## See `SkippableInst` for supported type kinds.
  assert skip <= SkippableInst, "`skip` contains unsupported type kinds: " & $(skip - SkippableInst)
  result = getTypeInst(n).applyLineInfo(n)
  if result.typeKind in skip:
    case result.typeKind
    of ntyTypeDesc:
      result = getTypeInstSkip(result[1], skip)
    else:
      discard "return as is"

proc getTypeImplSkip*(n: NimNode, skip = Skippable): NimNode =
  ## Obtain the type implementation of `n`, while skipping through type kinds matching `skip`.
  result = getTypeImpl:
    getTypeSkip(n, skip)
  result = result.applyLineInfo(n)

func newTypedesc*(n: NimNode): NimNode =
  ## Create a typedesc[n]
  nnkBracketExpr.newTree(bindSym"typedesc", copy(n))


proc skipSink(n: NimNode): NimNode = 
  if n.kind == nnkBracketExpr and n[0].eqIdent"sink":
    n[1]
  else:
    n

func sameType*(a, b: NimNode): bool =
  ## A variant of sameType to workaround:
  ##
  ## * https://github.com/nim-lang/Nim/issues/18867
  ##
  ## * https://github.com/nim-lang/Nim/issues/19072

  let
    a = a.skipSink()
    b = b.skipSink()

  # XXX: compiler bug workaround; see https://github.com/nim-lang/Nim/issues/18867
  if macros.sameType(a, b) or macros.sameType(b, a):
    # XXX: compiler bug workaround; see https://github.com/nim-lang/Nim/issues/19072

    # In case the types are generic parmeters
    if a.typeKind == ntyGenericParam and b.typeKind == ntyGenericParam:
      # The result will be whether they are the same symbol. This is due to
      # sameType() treating uninstantiated generics to be the same.
      a == b
    else:
      true
  else:
    false
