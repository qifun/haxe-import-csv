/*
 * haxe-import-csv
 * Copyright 2014 深圳岂凡网络有限公司 (Shenzhen QiFun Network Corp., LTD)
 *
 * Author: 杨博 (Yang Bo) <pop.atry@gmail.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.qifun.qforce.importCsv;

import com.dongxiguo.continuation.Continuation;
import com.dongxiguo.continuation.utils.Generator;
import com.qifun.qforce.importCsv.CsvParser;
import com.qifun.qforce.importCsv.error.ImporterError;
import haxe.ds.StringMap;
import haxe.ds.Vector;
import haxe.io.Bytes;
import haxe.io.Eof;
import haxe.io.Input;
import haxe.macro.Type;
import haxe.macro.Expr;
import haxe.zip.Entry;
import haxe.zip.Reader;
import haxe.macro.*;
import haxe.zip.Uncompress;
using StringTools;
using Lambda;
using com.qifun.util.locale.Translator;

typedef Worksheet =
{
  var fileName(default, never):String;
  var pack(default, never):Array<String>;
  var workbookName(default, never):String;
  var worksheetName(default, never):String;
  var data(default, never):CsvParser.CsvTable;
}

private interface IHaxeParser
{

  function parseInlineHaxe(code:String, position:Position):Expr;

  function parseHaxe(code:String, position:Position):Expr;

}

@:nativeGen
@:final
class ParserDefine
{

  public var flag(default, null):String;

  public var value(default, null):Null<String>;

  public function new(flag:String, ?value:String)
  {
    this.flag = flag;
    this.value = value;
  }

}

#if (!macro)
@:final
private class SimnParser implements IHaxeParser
{
  var defines:Vector<ParserDefine>;

  public function new(defines:Vector<ParserDefine>)
  {
    this.defines = defines;
  }

  function parse(code:String, position:Position):Expr return
  {
    var p = PositionTools.getInfos(position);
    var parser = new haxeparser.HaxeParser(byte.ByteData.ofString(code), p.file);
    for (d in defines)
    {
      parser.define(d.flag, d.value);
    }
    parser.expr();
  }

  public function parseInlineHaxe(code:String, position:Position):Expr return
  {
    parse(code, position);
  }

  public function parseHaxe(code:String, position:Position):Expr return
  {
    parse(code, position);
  }

}
#end

#if macro
@:final
private class MacroParser implements IHaxeParser
{
  public function new() { }

  public function parseInlineHaxe(code:String, position:Position):Expr return
  {
    Context.parseInlineString(code, position);
  }

  public function parseHaxe(code:String, position:Position):Expr return
  {
    Context.parse(code, position);
  }

}
#end

@:final
class Importer
{

  static var IMPORTED_ROW_TYPE_PATH(default, never):TypePath =
  {
    pack: [ "com", "qifun", "qforce", "importCsv" ],
    name: "ImportedRow",
  }

  #if sys
  static var DOT_SEPERATOR_EREG(default, never) = ~/[\.]/g;

  public static function generateSources(
    baseCsvPath:String,
    csvFilePaths:Iterable<String>,
    generateTo:String
    #if (!macro) , ?defines:Vector<ParserDefine> #end
    ):Array<String> return
  {
    #if (!macro)
    if (defines == null)
    {
      defines = new Vector<ParserDefine>(0);
    }
    #end
    var csvEntries =
    [
      for (csvFilePath in csvFilePaths)
      {
        readWorksheet(csvFilePath, '$baseCsvPath/$csvFilePath');
      }
    ];
    var moduleDefinitions = buildModuleDefinitions(csvEntries, #if macro new MacroParser() #else new SimnParser(defines) #end);
    [
      for (moduleDefinition in moduleDefinitions)
      {
        var fileName = generateTo + "/" + DOT_SEPERATOR_EREG.replace(moduleDefinition.modulePath, "/") + ".hx";
        var parent = fileName.substring(0, fileName.lastIndexOf("/"));
        if (!sys.FileSystem.exists(parent))
        {
          sys.FileSystem.createDirectory(parent);
        }
        var output = sys.io.File.write(fileName);
        try
        {
          var isFirstType = true;
          for (type in moduleDefinition.types)
          {
            if (isFirstType)
            {
              isFirstType = false;
              output.writeString("package ");
              output.writeString(type.pack.join("."));
              output.writeString(";\n");
              #if using_worksheet
              for (importExpr in moduleDefinition.imports)
              {
                switch (importExpr.mode)
                {
                  case INormal:
                  {
                    output.writeString("import ");
                    output.writeString(importExpr.path.map(function(field) return field.name).join("."));
                    output.writeString(";\n");
                  }
                  case IAsName(alias):
                  {
                    output.writeString("import ");
                    output.writeString(importExpr.path.map(function(field) return field.name).join("."));
                    output.writeString("as");
                    output.writeString(alias);
                    output.writeString(";\n");
                  }
                  case IAll:
                  {
                    output.writeString("import ");
                    output.writeString(importExpr.path.map(function(field) return field.name).join("."));
                    output.writeString(".*;\n");
                  }
                }

              }
              for (usingPath in moduleDefinition.usings)
              {
                output.writeString("using ");
                for (field in usingPath.pack)
                {
                  output.writeString(field);
                  output.writeString(".");
                }
                output.writeString(usingPath.name);
                if (usingPath.sub != null)
                {
                  output.writeString(".");
                  output.writeString(usingPath.sub);
                }
                output.writeString(";\n");
              }
              #end
            }
            output.writeString(new Printer().printTypeDefinition(type, false));
            output.writeByte("\n".code);
          }
        }
        catch (e:Dynamic)
        {
          output.close();
          throw e;
        }
        output.close();
        fileName;
      }
    ];
  }
  #end

  #if sys

  static var PATH_SEPERATOR_EREG(default, never) = ~/[\/\\]/g;

  static function readWorksheet(csvFilePath:String, resolvedPath:String):Worksheet return
  {
    var input = sys.io.File.read(resolvedPath);
    var data = try
    {
      CsvParser.parseInput(input);
    }
    catch (e:Dynamic)
    {
      input.close();
      #if neko
      neko.Lib.rethrow(e);
      #else
      throw e;
      #end
    }
    input.close();
    var csvFileEReg = ~/^(.*)[\/\\]([^\/\\\.]+)\.[^\/\\\.]+\.([^\/\\\.]+)\.utf-8\.csv$/;
    if (csvFileEReg.match(csvFilePath))
    {
      workbookName: csvFileEReg.matched(2),
      worksheetName: csvFileEReg.matched(3),
      pack: PATH_SEPERATOR_EREG.split(csvFileEReg.matched(1)),
      fileName: resolvedPath,
      data: data,
    }
    else
    {
      throw new InvalidCsvFileName(
        0,
        0,
        resolvedPath);
    }
  }
  #end

  /**
    把CSV文件导入为Haxe类型。

    这些CSV文件应该位于Haxe类路径，并以UTF-8编码。

    用法：
    `
    haxe --macro "com.qifun.qforce.importCsv.Importer.importCsvFile(['myPackage/ModuleName.xlsx.ClassName1.utf-8.csv','myPackage/ModuleName.xlsx.ClassName2.utf-8.csv'])"
    `
  **/
  macro public static function importCsv(csvFilePaths:Iterable<String>):Void
  {
    var moduleDefinitions = try
    {
      var csvEntries =
      [
        for (csvFilePath in csvFilePaths)
        {
          readWorksheet(csvFilePath, Context.resolvePath(csvFilePath));
        }
      ];
      buildModuleDefinitions(csvEntries, new MacroParser());
    }
    catch (e:ImporterError)
    {
      Context.error(e.message, PositionTools.make(e));
    }

    for (moduleDefinition in moduleDefinitions)
    {
      //for (t in moduleDefinition.types) trace(new Printer().printTypeDefinition(t));
      #if using_worksheet
      Context.defineModule(
        moduleDefinition.modulePath,
        moduleDefinition.types,
        moduleDefinition.imports,
        moduleDefinition.usings);
      #else
      Context.defineModule(
        moduleDefinition.modulePath,
        moduleDefinition.types);
      #end
    }
  }

  static var DUMMY_FUNCTION(default, never) = Reflect.makeVarArgs(function(_) { });

  static var IMPORT_EREG(default, never) = ~/^(﻿)?[\t\n\r ]*(([a-zA-Z0-9_]+|[\t\n\r ]*\.[\t\n\r ]*)+)((\.[\t\n\r ]*\*[\t\n\r ]*)|[\t\n\r ]+in[\t\n\r ]+([a-zA-Z0-9_]*)[\t\n\r ]*)?[\t\n\r ]*$/;

  static var USING_EREG(default, never) = ~/^(﻿)?[\t\n\r ]*(([a-z][a-zA-Z0-9_]*([\t\n\r ]*\.[\t\n\r ]*[a-z][a-zA-Z0-9_]*)*)[\t\n\r ]*\.)?[\t\n\r ]*([A-Z][a-zA-Z0-9_]*)[\t\n\r ]*(\.[\t\n\r ]*([A-Z][a-zA-Z0-9_]*))?[\t\n\r ]*$/;

  static var DOT_EREG(default, never) = ~/[\t\n\r ]*\.[\t\n\r ]*/g;

  public static function buildModuleDefinitions(csvEntries:Iterable<Worksheet>, parser:IHaxeParser):Iterable<
    {
      var modulePath(default, never):String;
      var types(default, never):Array<TypeDefinition>;
      #if using_worksheet
      var imports(default, never):Array<ImportExpr>;
      var usings(default, never):Array<TypePath>;
      #end
    }> return
  {

    function parseParameters(
      content:String,
      fileName:String,
      positionMin:Int,
      positionMax:Int):Array<Field> return
    {
      var expr = parser.parseHaxe('var _:{$content\n}', PositionTools.make(
        {
          min: positionMin,
          max: positionMax,
          file: fileName,
        }));
      switch (expr)
      {
        case
        {
          pos: _,
          expr: EVars(
            [
              {
                name: "_",
                expr: null,
                type: TAnonymous(fields),
              }
            ]),
        }:
        {
          fields;
        }
        case { pos: PositionTools.getInfos(_) => p } :
        {
          throw new ExpectVar(
            Std.int(Math.max(p.min, positionMin)),
            Std.int(Math.min(p.max, positionMax)),
            fileName);
        }
      }
    }

    function parseHead(
      content:String,
      fileName:String,
      positionMin:Int,
      positionMax:Int):Field return
    {
      var expr = parser.parseHaxe('var _:{$content\n}', PositionTools.make(
        {
          min: positionMin,
          max: positionMax,
          file: fileName,
        }));
      switch (expr)
      {
        case
        {
          pos: _,
          expr: EVars(
            [
              {
                name: "_",
                expr: null,
                type: TAnonymous([ ]),
              }
            ]),
        }:
        {
          null;
        }
        case
        {
          pos: _,
          expr: EVars(
            [
              {
                name: "_",
                expr: null,
                type: TAnonymous([ field ]),
              }
            ])
        }:
        {
          field;
        }
        case { pos: PositionTools.getInfos(_) => p } :
        {
          throw new ExpectField(
            Std.int(Math.max(p.min, positionMin)),
            Std.int(Math.min(p.max, positionMax)),
            fileName);
        }
      }
    }

    function parseRowId(
      content:String,
      fileName:String,
      positionMin:Int,
      positionMax:Int,
      classMeta:Metadata):Null<String> return
    {
      var expr0 = parser.parseInlineHaxe('$content\n-_', PositionTools.make(
        {
          min: positionMin,
          max: positionMax,
          file: fileName,
        }));
      function extractRowId(expr0:Expr):String return
      {
        switch (expr0)
        {
          case { pos: _, expr: EConst(CIdent(name)) }:
          {
            name;
          }
          case { pos: _, expr: EMeta(s, e) } :
          {
            classMeta.push(s);
            extractRowId(e);
          }
          case { pos: PositionTools.getInfos(_) => p } :
          {
            throw new ExpectMetaOrRowId(
              Std.int(Math.max(p.min, positionMin)),
              Std.int(Math.min(p.max, positionMax)),
              fileName);
          }
        }
      }
      switch (expr0)
      {
        case { pos: _, expr: EBinop(Binop.OpSub, idOrMeta, { pos: _, expr: EConst(CIdent("_")) } ) }:
        {
          extractRowId(idOrMeta);
        }
        case { pos: _, expr: EUnop(Unop.OpNeg, false, { pos: _, expr: EConst(CIdent("_")) } ) }:
        {
          null;
        }
        case { pos: PositionTools.getInfos(_) => p } :
        {
          throw new ExpectMetaOrRowId(
            Std.int(Math.max(p.min, positionMin)),
            Std.int(Math.min(p.max, positionMax)),
            fileName);
        }
      }
    }
    var mainClassFieldsByModule = new StringMap<Array<Field>>();
    var baseRowFieldsByModule = new StringMap<Array<Field>>();
    var workbookModules = new StringMap<Array<TypeDefinition>>();
    #if using_worksheet
    var workbookImports = new StringMap<Array<ImportExpr>>();
    var workbookUsings = new StringMap<Array<TypePath>>();
    #end
    for (csvEntry in csvEntries)
    {
      var csvFileName = csvEntry.fileName;
      var workbookName = csvEntry.workbookName;
      var pack = csvEntry.pack;
      var module = pack.concat([ workbookName ]);
      var fullModuleName = module.join(".");
      switch (csvEntry.worksheetName)
      {
        #if using_worksheet
        case "import":
        {
          var imports:Array<ImportExpr> = [];
          for (row in csvEntry.data)
          {
            for (cell in row)
            {
              switch (cell.content)
              {
                case null, "":
                {
                  continue;
                }
                case importPath:
                {
                  if (IMPORT_EREG.match(importPath))
                  {
                    imports.push(
                      {
                        path:
                        [
                          for (name in DOT_EREG.split(IMPORT_EREG.matched(2)))
                          {
                            pos: PositionTools.here(),
                            name: name,
                          }
                        ],
                        mode: switch ([IMPORT_EREG.matched(5), IMPORT_EREG.matched(6)])
                        {
                          case [ null, null ]:
                          {
                            ImportMode.INormal;
                          }
                          case [ null, alias ]:
                          {
                            ImportMode.IAsName(alias);
                          }
                          case [ _, null ]:
                          {
                            ImportMode.IAll;
                          }
                          default:
                          {
                            throw "Cannot match both IAsName as IAll";
                          }
                        }
                      });
                  }
                  else
                  {
                    throw new ExpectImportExpr(cell.positionMin, cell.positionMax, csvFileName);
                  }
                }
              }
            }
          }
          workbookImports.set(fullModuleName, imports);
          continue;
        }
        case "using":
        {
          var usings:Array<TypePath> = [];
          for (row in csvEntry.data)
          {
            for (cell in row)
            {
              switch (cell.content)
              {
                case null, "":
                {
                  continue;
                }
                case usingPath:
                {
                  if (USING_EREG.match(usingPath))
                  {
                    usings.push(
                      {
                        pack: switch (USING_EREG.matched(3))
                        {
                          case null, "": [];
                          case path: DOT_EREG.split(path);
                        },
                        name: USING_EREG.matched(5),
                        sub: USING_EREG.matched(7),
                      });
                  }
                  else
                  {
                    throw new ExpectTypePath(cell.positionMin, cell.positionMax, csvFileName);
                  }
                }
              }
            }
          }
          workbookUsings.set(fullModuleName, usings);
          continue;
        }
        #end
        case worksheetName:
        {
          var baseClassName = workbookName + "_Row";
          var externalBridgeClassName = worksheetName + "_ExternalBridge";
          var bridgeClassName = worksheetName + "_Bridge";
          var moduleExpr = switch (MacroStringTools.toFieldExpr(pack))
          {
            case null:
            {
              macro $i{workbookName};
            }
            case packExpr:
            {
              macro $packExpr.$workbookName;
            }
          }
          var mainClassFields:Array<Field>;
          var baseRowFields:Array<Field>;
          var workbookModule:Array<TypeDefinition>;
          if (workbookModules.exists(fullModuleName))
          {
            mainClassFields = mainClassFieldsByModule.get(fullModuleName);
            baseRowFields = baseRowFieldsByModule.get(fullModuleName);
            workbookModule = workbookModules.get(fullModuleName);
          }
          else
          {
            mainClassFields = [];
            mainClassFieldsByModule.set(fullModuleName, mainClassFields);
            baseRowFields = [];
            baseRowFieldsByModule.set(fullModuleName, baseRowFields);
            workbookModule = [];
            workbookModule.push(
            {
              name: workbookName,
              pack: pack,
              pos: PositionTools.here(),
              kind: TDClass(),
              fields: mainClassFields,
              meta:
              [
                {
                  name: ":nativeGen",
                  pos: PositionTools.here(),
                }
              ]
            });
            workbookModule.push(
            {
              name: baseClassName,
              pack: pack,
              pos: PositionTools.here(),
              kind: TDClass(IMPORTED_ROW_TYPE_PATH),
              meta:
              [
                {
                  name: ":nativeGen",
                  pos: PositionTools.here(),
                },
                {
                  name: ":allow",
                  params: [ moduleExpr ],
                  pos: PositionTools.here(),
                }
              ],
              fields: baseRowFields,
            });
            workbookModules.set(fullModuleName, workbookModule);
          }

          function getPosition(cell:CsvCell):Position return
          {
            PositionTools.make(
              {
                min: cell.positionMin,
                max: cell.positionMax,
                file: csvFileName,
              });
          }

          var csvData = csvEntry.data;
          var headRow = csvData[0];
          var headPos = getPosition(headRow[0]);
          var numColumnsRequired = headRow.length;
          var fieldBuilders = [];
          var externalBridgeFields:Array<Field> = [];
          var bridgeFields:Array<Field> = [];
          for (x in 2...numColumnsRequired)
          {
            var builderIndex = x - 2;
            var headCell = headRow[x];
            var headCellPos = getPosition(headCell);
            var sourceField = parseHead(headCell.content, csvFileName, headCell.positionMin, headCell.positionMax);
            if (sourceField == null)
            {
              fieldBuilders[builderIndex] = DUMMY_FUNCTION;
            }
            else
            {
              switch (sourceField.kind)
              {
                case FVar(t, null):
                {
                  var fieldName = sourceField.name;
                  var getterName = 'get_$fieldName';
                  // The getter method in Haxe.
                  externalBridgeFields.push(
                    {
                      pos: headCellPos,
                      name: getterName,
                      meta:
                      [
                        { pos: headCellPos, name: ":noCompletion" },
                      ],
                      kind: FFun(
                        {
                          args: [],
                          ret: t,
                          expr: null,
                        }),
                    });
                  // The getter method in Haxe.
                  bridgeFields.push(
                    {
                      pos: headCellPos,
                      name: getterName,
                      meta:
                      [
                        { pos: headCellPos, name: ":noCompletion" },
                      ],
                      kind: FFun(
                        {
                          args: [],
                          ret: t,
                          expr: macro return throw "Not implemented!",
                        }),
                    });
                  // The getter method for Scala.
                  bridgeFields.push(
                    {
                      pos: headCellPos,
                      name: fieldName,
                      meta:
                      [
                        { pos: headCellPos, name: ":noCompletion" },
                      ],
                      kind: FFun(
                        {
                          args: [],
                          ret: t,
                          expr: macro return this.$getterName(),
                        }),
                    });
                }
                default:
                {
                  // 无需生成桥接代码
                }
              }
              fieldBuilders[builderIndex] = function(cell:CsvCell, isDefaultRow:Bool, fieldOutput:Array<Field>):Void
              {
                var cellExpr = switch (cell.content)
                {
                  case null, "" if (!isDefaultRow):
                  {
                    // 无需设置，使用默认值即可
                    return;
                  }
                  case null, "":
                  {
                    macro cast null;
                  }
                  case fieldBody:
                  {
                    var cellContentExpr =
                    {
                      expr: EConst(CString(fieldBody)),
                      pos: getPosition(cell),
                    };
                    macro com.qifun.qforce.importCsv.Importer.ImporterRuntime.parseCell($cellContentExpr);
                  }
                }
                var newAccess = switch (sourceField.access)
                {
                  case originalAccess if (originalAccess.foreach(function(a) return a.match(APrivate | AInline))):
                  {
                    var newAccess = originalAccess.copy();
                    if (!originalAccess.exists(function(a) return a.match(APrivate)))
                    {
                      newAccess.push(APublic);
                    }
                    if (sourceField.kind.match(FFun(_)) && !isDefaultRow)
                    {
                      newAccess.push(AOverride);
                    }
                    newAccess;
                  }
                  default:
                  {
                    var p = PositionTools.getInfos(sourceField.pos);
                    throw new UnexpectedAccess(p.min, p.max, p.file);
                  }
                }
                switch (sourceField.kind)
                {
                  case FFun( { expr: null, args: args, ret: ret, params: null | [] } ):
                  {
                    fieldOutput.push(
                      {
                        name: sourceField.name,
                        doc: sourceField.doc,
                        access: newAccess,
                        pos: sourceField.pos,
                        meta: sourceField.meta,
                        kind: FFun(
                          {
                            args: args,
                            ret: ret,
                            expr: macro return $cellExpr,
                          })
                      });
                  }
                  case FFun( { expr: { pos: pos } } ):
                  {
                    var p = PositionTools.getInfos(pos);
                    throw new UnexpectedFunctionBody(p.min, p.max, p.file);
                  }
                  case FVar(t, null):
                  {
                    var fieldName = sourceField.name;
                    var underlyingFieldName = '_$fieldName';
                    if (isDefaultRow)
                    {
                      fieldOutput.push(
                        {
                          name: fieldName,
                          doc: sourceField.doc,
                          access: newAccess,
                          pos: sourceField.pos,
                          meta: sourceField.meta,
                          kind: FProp(
                            "get",
                            "never",
                            t)
                        });
                      fieldOutput.push(
                        {
                          name: underlyingFieldName,
                          doc: sourceField.doc,
                          access: [ ],
                          pos: sourceField.pos,
                          meta: sourceField.meta.concat(
                            [
                              { pos: sourceField.pos, name: ":transient" },
                              { pos: sourceField.pos, name: ":noCompletion" },
                              { pos: sourceField.pos, name: ":protected" },
                            ]),
                          kind: FVar(
                            TPath(
                              {
                                name: "Null",
                                pack: [ ],
                                params: [ TPType(t) ],
                              }))
                        });
                    }
                    fieldOutput.push(
                      {
                        name: 'get_$fieldName',
                        doc: sourceField.doc,
                        access: [ AOverride ],
                        pos: sourceField.pos,
                        meta: sourceField.meta.concat(
                          [
                            { pos: sourceField.pos, name: ":noCompletion" },
                          ]),
                        kind: FFun(
                          {
                            args: [],
                            ret: t,
                            expr: macro return
                            {
                              if ($i{underlyingFieldName} == null)
                              {
                                $i{underlyingFieldName} = $cellExpr;
                              }
                              $i{underlyingFieldName};
                            },
                          }),
                      });
                  }
                  case FVar(_, { pos: pos }):
                  {
                    var p = PositionTools.getInfos(pos);
                    throw new UnexpectedVarInitializer(p.min, p.max, p.file);
                  }
                  case FProp(_, _, _, _):
                  {
                    var p = PositionTools.getInfos(sourceField.pos);
                    throw new PropertyIsNotSupported(p.min, p.max, p.file);
                  }
                }
              }
            }
          }
          var hasCustomBaseClass = false;
          function buildRow(row:Null<CsvRow>):Void
          {
            var numColumns = row == null ? 0 : row.length;
            var defaultCell = null;
            function getCell(x:Int):CsvCell return
            {
              if (x < numColumns)
              {
                row[x];
              }
              else if (defaultCell != null)
              {
                defaultCell;
              }
              else
              {
                defaultCell =
                {
                  content: "",
                  positionMin: row == null ? 0 : row[numColumns - 1].positionMin,
                  positionMax: row == null ? 0 : row[numColumns - 1].positionMax,
                }
              }
            }
            var cell0 = getCell(0);
            var pos0 = getPosition(cell0);
            var classMeta:Metadata =
            [
              {
                name: ":nativeGen",
                pos: pos0,
              },
            ];
            var rowId = if (row == null)
            {
              worksheetName;
            }
            else
            {
              parseRowId(cell0.content, csvFileName, cell0.positionMin, cell0.positionMax, classMeta);
            }
            if (rowId == null)
            {
              return;
            }
            var isDefaultRow = rowId == worksheetName;
            if (isDefaultRow)
            {
              hasCustomBaseClass = true;
            }
            if (isDefaultRow)
            {
              classMeta.push({ name: ":bridgeProperties", pos: pos0 });
              classMeta.push({ name: ":worksheetDefaultRow", pos: pos0 });
            }
            else
            {
              classMeta.push({ name: ":final", pos: pos0 });
              classMeta.push({ name: ":worksheetRow", pos: pos0 });
            }
            var cell1 = getCell(1);
            var parameters = parseParameters(cell1.content, csvFileName, cell1.positionMin, cell1.positionMax);
            var constructorArguments:Array<FunctionArg> = [];
            var initializationExprs = [ macro super() ];
            var fields:Array<Field> = [];
            var argumentExprs = [];
            for (parameter in parameters)
            {
              switch (parameter.kind)
              {
                case FVar(t, e), FProp("default" | "null", "default" | "null", t, e):
                {
                  var isOptional = e != null || parameter.meta.exists(function(m)return m.name == ":optional");
                  var parameterName = parameter.name;
                  fields.push(
                    {
                      name: parameterName,
                      doc: parameter.doc,
                      access: switch (parameter.access)
                      {
                        case _.has(AStatic) => true:
                        {
                          var p = PositionTools.getInfos(parameter.pos);
                          (throw new UnexpectedAccess(p.min, p.max, p.file):Array<Access>);
                        }
                        case a:
                        {
                          a;
                        }
                      },
                      kind: switch(parameter.kind)
                      {
                        case FVar(t, _):
                        {
                          FVar(isOptional ? TPath({ pack: [], name: "Null", params: [ TPType(t) ] }) : t);
                        }
                        case FProp(get, set, t, _):
                        {
                          FProp(get, set, isOptional ? TPath({ pack: [], name: "Null", params: [ TPType(t) ] }) : t);
                        }
                        default: (throw "Unreachable code!":FieldType);
                      },
                      pos: parameter.pos,
                      meta: parameter.meta,
                    });
                  initializationExprs.push(macro this.$parameterName = $i{parameterName});
                  constructorArguments.push(
                    {
                      name: parameterName,
                      opt: isOptional,
                      type: t,
                      value: e,
                    });
                  argumentExprs.push(macro $i{parameterName});
                }
                default:
                {
                  var p = PositionTools.getInfos(parameter.pos);
                  throw new ExpectVar(p.min, p.max, p.file);
                }
              }
            }
            fields.push(
              {
                name: "new",
                pos: pos0,
                access: [ APublic ],
                kind: FFun(
                  {
                    args: constructorArguments,
                    ret: null,
                    expr: { pos: pos0, expr: EBlock(initializationExprs) },
                  })
              });

            for (i in 0...fieldBuilders.length)
            {
              var x = i + 2;
              fieldBuilders[i](getCell(x), isDefaultRow, fields);
            }
            workbookModule.push(
              {
                pack: pack,
                name: rowId,
                pos: pos0,
                meta: classMeta,
                kind: TDClass(
                  if (isDefaultRow)
                  {
                    pack: pack,
                    name: workbookName,
                    sub: externalBridgeClassName,
                  }
                  else
                  {
                    pack: pack,
                    name: workbookName,
                    sub: worksheetName,
                  }),
                fields: fields,
              });
            var rowPath =
            {
              pack: pack,
              name: workbookName,
              sub: rowId,
            }

            if (constructorArguments.empty())
            {
              baseRowFields.push(
                {
                  name: 'get_$rowId',
                  pos: pos0,
                  access: [ AInline ],
                  meta:
                  [
                    { name: ":final", pos: pos0 },
                    { name: ":noCompletion", pos: pos0 },
                    { name: ":protected", pos: pos0 },
                    { name: ":extern", pos: pos0 }
                  ],
                  kind: FFun(
                    {
                      ret: TPath(rowPath),
                      args: [],
                      expr: macro return $i{workbookName}.$rowId,
                    }),
                });
              baseRowFields.push(
                {
                  name: rowId,
                  pos: pos0,
                  access: [ ],
                  meta: [ ],
                  kind: FProp("get", "never", TPath(rowPath), null)
                });
              mainClassFields.push(
                {
                  name: rowId,
                  pos: pos0,
                  access: [ AStatic, APublic ],
                  meta: [ { name: ":final", pos: pos0 } ],
                  kind: FProp("default", "never", null, macro new $rowPath())
                });
            }
            else
            {
              baseRowFields.push(
                {
                  name: rowId,
                  pos: pos0,
                  access: [ AInline ],
                  meta:
                  [
                    { name: ":final", pos: pos0 },
                    { name: ":protected", pos: pos0 },
                    { name: ":extern", pos: pos0 }
                  ],
                  kind: FFun(
                    {
                      ret: TPath(rowPath),
                      args: constructorArguments,
                      expr: macro return new $rowPath($a{argumentExprs}),
                    })
                });
              mainClassFields.push(
                {
                  name: rowId,
                  pos: pos0,
                  access: [ AInline, AStatic, APublic ],
                  meta:
                  [
                    { name: ":final", pos: pos0 },
                    { name: ":noUsing", pos: pos0 },
                  ],
                  kind: FFun(
                    {
                      ret: TPath(rowPath),
                      args: constructorArguments,
                      expr: macro return new $rowPath($a{argumentExprs}),
                    })
                });
            }
          }

          for (y in 1...csvData.length)
          {
            buildRow(csvData[y]);
          }

          if (!hasCustomBaseClass)
          {
            buildRow(null);
          }

          workbookModule.push(
            {
              pack: pack,
              name: externalBridgeClassName,
              pos: headPos,
              isExtern: true,
              meta:
              [
                {
                  pos: headPos,
                  name: ":native",
                  params:
                  [
                    {
                      expr: EConst(CString(pack.concat([ bridgeClassName ]).join("."))),
                      pos: headPos,
                    }
                  ],
                },
                {
                  pos: headPos,
                  name: ":nativeGen",
                }
              ],
              kind: TDClass(
                {
                  pack: pack,
                  name: workbookName,
                  sub: baseClassName,
                }),
              fields: externalBridgeFields,
            });
          workbookModule.push(
            {
              pack: pack,
              name: bridgeClassName,
              pos: headPos,
              meta:
              [
                {
                  pos: headPos,
                  name: ":nativeGen",
                }
              ],
              kind: TDClass(
                {
                  pack: pack,
                  name: workbookName,
                  sub: baseClassName,
                }),
              fields: bridgeFields,
            });
        }
      }
    }
    [
      for (fullModuleName in workbookModules.keys())
      {
        var workbookModule = workbookModules.get(fullModuleName);
        #if using_worksheet
        var imports = workbookImports.get(fullModuleName);
        var usings = workbookUsings.get(fullModuleName);
        #end
        {
          modulePath: fullModuleName,
          types: workbookModule,
          #if using_worksheet
          imports: imports == null ? [] : imports,
          usings: usings == null ? [] : usings,
          #end
        }
      }
    ];
  }

}

@:dox(hide)
class ImporterRuntime
{
  macro public static function parseCell(cellContent:ExprOf<String>):Expr return
  {
    function parseByType(expectedType:Type):Expr return
    {
      var baseType:BaseType = switch (expectedType)
      {
        case TInst(t, _): t.get();
        case TAbstract(t, _): t.get();
        case TType(t, _): t.get();
        default: throw "Unreachable code!";
      }
      for (entry in baseType.meta.get())
      {
        switch (entry)
        {
          case { name: ":parseCellFunction", params: [ functionExpr ] } :
          {
            return macro $functionExpr($cellContent);
          }
          default:
          {
            continue;
          }
        }
      }
      var followable = switch (expectedType)
      {
        case TMono(_): true;
        case TLazy(_): true;
        case TType(_, _): true;
        case TInst(_.get() => { kind: KGenericBuild }, _): true;
        default: false;
      }
      if (followable)
      {
        parseByType(Context.follow(expectedType, true));
      }
      else
      {
        switch (cellContent)
        {
          case { pos: pos, expr: EConst(CString(code)) }:
          {
            Context.parse(code + "\n", pos);
          }
          case { pos: pos } :
          {
            Context.error(Translator.translate("Expected \""), pos);
          }
        }
      }
    }
    parseByType(Context.getExpectedType());
  }
}

// vim: et sts=2 sw=2

