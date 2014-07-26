package com.qifun.qforce.importCsv;

import com.dongxiguo.continuation.Continuation;
import com.dongxiguo.continuation.utils.Generator;
import com.qifun.qforce.importCsv.CsvParser;
import haxe.ds.StringMap;
import haxe.ds.Vector;
import haxe.io.Bytes;
import haxe.io.Eof;
import haxe.io.Input;
import haxe.macro.Expr;
import haxe.zip.Entry;
import haxe.zip.Reader;
import haxe.macro.*;
import haxe.zip.Uncompress;
using StringTools;
using Lambda;
using com.qifun.locale.Translator;

typedef Worksheet =
{
  var fileName(default, never):String;
  var pack(default, never):Array<String>;
  var workbookName(default, never):String;
  var worksheetName(default, never):String;
  var data(default, never):CsvParser.CsvTable;
}

class ImporterError
{
  public var min:Int;
  public var max:Int;
  public var file:String;

  @:allow(com.qifun.qforce.importCsv.Importer)
  function new(min:Int, max:Int, file:String)
  {
    this.min = min;
    this.max = max;
    this.file = file;
  }

  public var message(get, never):String;

  function get_message() return "Import parsed CSV failed";

}

private class UnexpectedVarInitializer extends ImporterError
{

  override function get_message() return
  {
    Translator.translate("The var definition in first row must not include a initializer");
  }

}

private class UnexpectedAccess extends ImporterError
{

  override function get_message() return
  {
    Translator.translate("Unexpected access");
  }

}

private class UnexpectedFunctionBody extends ImporterError
{

  override function get_message() return
  {
    Translator.translate("The function definition in first row must not include a function body");
  }

}

private class PropertyIsNotSupported extends ImporterError
{

  override function get_message() return Translator.translate("Property is not supported");

}

private class ExpectField extends ImporterError
{

  override function get_message() return Translator.translate("Expected `function` or `var`");

}

private class ExpectVar extends ImporterError
{

  override function get_message() return Translator.translate("Expected `var`");

}

@:final
private class ExpectMetaOrItemId extends ImporterError
{

  override function get_message() return Translator.translate("Expected `@meta` or `ItemId`");

}

private class InvalidCsvFileName extends ImporterError
{

  override function get_message() return
  {
    Translator.translate("The file name should match *.*.utf-8.csv!");
  }

}

@:final
class Importer
{

  static var IMPORTED_ROW_TYPE_PATH(default, never):TypePath =
  {
    pack: [ "com", "qifun", "qforce", "importCsv" ],
    name: "IImportedRow",
  }

  #if sys
  static var DOT_SEPERATOR_EREG(default, never) = ~/[\.]/g;

  public static function generateSources(baseCsvPath:String, csvFilePaths:Iterable<String>, generateTo:String):Array<String> return
  {
    var csvEntries =
    [
      for (csvFilePath in csvFilePaths)
      {
        readWorksheet(csvFilePath, '$baseCsvPath/$csvFilePath');
      }
    ];
    var moduleDefinitions = buildModuleDefinitions(csvEntries);
    [
      for (moduleDefinition in moduleDefinitions)
      {
        var fileName = generateTo + "/" + DOT_SEPERATOR_EREG.replace(moduleDefinition.modulePath, "/") + ".hx";
        var output = sys.io.File.write(DOT_SEPERATOR_EREG.replace(moduleDefinition.modulePath, "/") + ".hx");
        try
        {
          var isFirstType = true;
          for (type in moduleDefinition.types)
          {
            new Printer().printTypeDefinition(type, isFirstType);
            if (isFirstType)
            {
              isFirstType = false;
            }
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
      buildModuleDefinitions(csvEntries);
    }
    catch (e:ImporterError)
    {
      Context.error(e.message, PositionTools.make(e));
    }

    for (moduleDefinition in moduleDefinitions)
    {
      //for (t in moduleDefinition.types) trace(new Printer().printTypeDefinition(t));
      Context.defineModule(moduleDefinition.modulePath, moduleDefinition.types);
    }
  }

  static function parseInlineHaxe(code:String, position:Position):Expr return
  {
    #if macro
      Context.parseInlineString(code, position);
    #else
      var p = PositionTools.getInfos(position);
      var parser = new haxeparser.HaxeParser(byte.ByteData.ofString(code), p.file);
      parser.expr();
    #end
  }

  static function parseHaxe(code:String, position:Position):Expr return
  {
    #if macro
      Context.parse(code, position);
    #else
      var p = PositionTools.getInfos(position);
      var parser = new haxeparser.HaxeParser(byte.ByteData.ofString(code), p.file);
      parser.expr();
    #end
  }

  static function parseParameters(
    content:String,
    fileName:String,
    positionMin:Int,
    positionMax:Int):Array<Field> return
  {
    var expr = parseHaxe('var _:{$content\n}', PositionTools.make(
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

  static function parseHead(
    content:String,
    fileName:String,
    positionMin:Int,
    positionMax:Int):Field return
  {
    var expr = parseHaxe('var _:{$content\n}', PositionTools.make(
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

  static function parseItemId(
    content:String,
    fileName:String,
    positionMin:Int,
    positionMax:Int,
    classMeta:Metadata):Null<String> return
  {
    var expr0 = parseInlineHaxe('$content\n-_', PositionTools.make(
      {
        min: positionMin,
        max: positionMax,
        file: fileName,
      }));
    function extractItemId(expr0:Expr):String return
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
          extractItemId(e);
        }
        case { pos: PositionTools.getInfos(_) => p } :
        {
          throw new ExpectMetaOrItemId(
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
        extractItemId(idOrMeta);
      }
      case { pos: _, expr: EUnop(Unop.OpNeg, false, { pos: _, expr: EConst(CIdent("_")) } ) }:
      {
        null;
      }
      case { pos: PositionTools.getInfos(_) => p } :
      {
        throw new ExpectMetaOrItemId(
          Std.int(Math.max(p.min, positionMin)),
          Std.int(Math.min(p.max, positionMax)),
          fileName);
      }
    }
  }

  static var DUMMY_FUNCTION(default, never) = Reflect.makeVarArgs(function(_) { });

  public static function buildModuleDefinitions(csvEntries:Iterable<Worksheet>):Iterable<
    {
      var modulePath(default, never):String;
      var types(default, never):Array<TypeDefinition>;
    }> return
  {
    var mainClassFieldsByModule = new StringMap<Array<Field>>();
    var baseItemFieldsByModule = new StringMap<Array<Field>>();
    var workbookModules = new StringMap<Array<TypeDefinition>>();
    for (csvEntry in csvEntries)
    {
      var csvFileName = csvEntry.fileName;
      var workbookName = csvEntry.workbookName;
      var worksheetName = csvEntry.worksheetName;
      var pack = csvEntry.pack;
      var baseClassName = workbookName + "_Base";
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
      var module = pack.concat([ workbookName ]);
      var fullModuleName = module.join(".");
      var mainClassFields:Array<Field>;
      var baseItemFields:Array<Field>;
      var workbookModule:Array<TypeDefinition>;
      if (workbookModules.exists(fullModuleName))
      {
        mainClassFields = mainClassFieldsByModule.get(fullModuleName);
        baseItemFields = baseItemFieldsByModule.get(fullModuleName);
        workbookModule = workbookModules.get(fullModuleName);
      }
      else
      {
        mainClassFields = [];
        mainClassFieldsByModule.set(fullModuleName, mainClassFields);
        baseItemFields =
        [
          {
            name: "new",
            pos: PositionTools.here(),
            access: [ APrivate, AInline ],
            kind: FFun(
              {
                args: [],
                ret: null,
                expr: macro null,
              }),
          }
        ];
        baseItemFieldsByModule.set(fullModuleName, baseItemFields);
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
          kind: TDClass(null, [ IMPORTED_ROW_TYPE_PATH ]),
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
          fields: baseItemFields,
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
              externalBridgeFields.push(
                {
                  pos: headCellPos,
                  name: getterName,
                  kind: FFun(
                    {
                      args: [],
                      ret: t,
                      expr: null,
                    }),
                });
              bridgeFields.push(
                {
                  pos: headCellPos,
                  name: getterName,
                  kind: FFun(
                    {
                      args: [],
                      ret: t,
                      expr: macro return throw "Not implemented!",
                    }),
                });
              bridgeFields.push(
                {
                  pos: headCellPos,
                  name: fieldName,
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
          fieldBuilders[builderIndex] = function(cell:CsvCell, isDefaultItem:Bool, fieldOutput:Array<Field>):Void
          {
            var cellExpr = switch (cell.content)
            {
              case null, "" if (!isDefaultItem):
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
                parseHaxe(fieldBody, getPosition(cell));
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
                if (sourceField.kind.match(FFun(_)) && !isDefaultItem)
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
                if (isDefaultItem)
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
                    meta: sourceField.meta,
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
        var itemId = if (row == null)
        {
          worksheetName;
        }
        else
        {
          parseItemId(cell0.content, csvFileName, cell0.positionMin, cell0.positionMax, classMeta);
        }
        if (itemId == null)
        {
          return;
        }
        var isDefaultItem = itemId == worksheetName;
        if (isDefaultItem)
        {
          hasCustomBaseClass = true;
        }
        if (isDefaultItem)
        {
          classMeta.push({ name: ":bridgeProperties", pos: pos0 });
        }
        else
        {
          classMeta.push({ name: ":final", pos: pos0 });
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
          fieldBuilders[i](getCell(x), isDefaultItem, fields);
        }
        workbookModule.push(
          {
            pack: pack,
            name: itemId,
            pos: pos0,
            meta: classMeta,
            kind: TDClass(
              if (isDefaultItem)
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
        var itemPath =
        {
          pack: pack,
          name: workbookName,
          sub: itemId,
        }

        if (constructorArguments.empty())
        {
          baseItemFields.push(
            {
              name: 'get_$itemId',
              pos: pos0,
              access: [ AInline ],
              meta: [ { name: ":final", pos: pos0 }, { name: ":protected", pos: pos0 } ],
              kind: FFun(
                {
                  ret: TPath(itemPath),
                  args: [],
                  expr: macro return $i{workbookName}.$itemId,
                }),
            });
          baseItemFields.push(
            {
              name: itemId,
              pos: pos0,
              access: [ ],
              meta: [ { name: ":final", pos: pos0 } ],
              kind: FProp("get", "never", TPath(itemPath), null)
            });
          mainClassFields.push(
            {
              name: itemId,
              pos: pos0,
              access: [ AStatic, APublic ],
              meta: [ { name: ":final", pos: pos0 } ],
              kind: FProp("default", "never", null, macro new $itemPath())
            });
        }
        else
        {
          baseItemFields.push(
            {
              name: itemId,
              pos: pos0,
              access: [ AInline ],
              meta: [ { name: ":final", pos: pos0 }, { name: ":protected", pos: pos0 } ],
              kind: FFun(
                {
                  ret: TPath(itemPath),
                  args: constructorArguments,
                  expr: macro return new $itemPath($a{argumentExprs}),
                })
            });
          mainClassFields.push(
            {
              name: itemId,
              pos: pos0,
              access: [ AInline, AStatic, APublic ],
              meta: [ { name: ":final", pos: pos0 } ],
              kind: FFun(
                {
                  ret: TPath(itemPath),
                  args: constructorArguments,
                  expr: macro return new $itemPath($a{argumentExprs}),
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

    [
      for (fullModuleName in workbookModules.keys())
      {
        var workbookModule = workbookModules.get(fullModuleName);
        {
          modulePath: fullModuleName,
          types: workbookModules.get(fullModuleName),
        }
      }
    ];
  }

}

// vim: et sts=2 sw=2
