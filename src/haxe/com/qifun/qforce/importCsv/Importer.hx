package com.qifun.qforce.importCsv;


import com.dongxiguo.continuation.Continuation;
import com.dongxiguo.continuation.utils.Generator;
import com.qifun.qforce.importCsv.CsvParser;
import haxe.ds.StringMap;
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
using com.qifun.qforce.importCsv.Translation;

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
    Translation.translate("The var definition in first row must not include a initializer");
  }

}

private class UnexpectedAccess extends ImporterError
{

  override function get_message() return
  {
    Translation.translate("Unexpected access");
  }

}

private class UnexpectedFunctionBody extends ImporterError
{

  override function get_message() return
  {
    Translation.translate("The function definition in first row must not include a function body");
  }

}

private class PropertyIsNotSupported extends ImporterError
{

  override function get_message() return Translation.translate("Property is not supported");

}

private class ExpectField extends ImporterError
{

  override function get_message() return Translation.translate("Expected `function` or `var`");

}

@:final
private class ExpectMetaOrItemId extends ImporterError
{

  override function get_message() return Translation.translate("Expected `@meta` or `ItemId`");

}

@:final
class Importer
{
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
    var csvFileEReg = ~/^(.*)[\/\\]([^\/\\\.]+)\.[^\/\\\.]+\.([^\/\\\.]+)\.utf-8\.csv$/;
    var pathSeperatorEReg = ~/[\/\\]/g;
    var csvEntries =
    [
      for (csvFilePath in csvFilePaths)
      {
        var resolvedPath = Context.resolvePath(csvFilePath);
        var input = sys.io.File.read(resolvedPath);
        var data = try
        {
          CsvParser.parseInput(input);
        }
        catch (e:CsvParserError)
        {
          input.close();
          Context.error(e.message, Context.makePosition(
            {
              min: e.positionMin,
              max: e.positionMax,
              file: resolvedPath,
            }));
        }
        catch (e:Dynamic)
        {
          input.close();
          neko.Lib.rethrow(e);
        }
        input.close();
        if (csvFileEReg.match(csvFilePath))
        {
          workbookName: csvFileEReg.matched(2),
          worksheetName: csvFileEReg.matched(3),
          pack: pathSeperatorEReg.split(csvFileEReg.matched(1)),
          fileName: resolvedPath,
          data: data,
        }
        else
        {
          Context.error(
            'The file name should match ${csvFileEReg}!',
            PositionTools.make(
              {
                file: resolvedPath,
                min: 0,
                max: 0,
              }));
        }
      }
    ];

    var moduleDefinitions = try
    {
      buildModuleDefinitions(csvEntries);
    }
    catch (e:ImporterError)
    {
      Context.error(e.message, PositionTools.make(e));
    }

    for (moduleDefinition in moduleDefinitions)
    {
      for (t in moduleDefinition.types) trace(new Printer().printTypeDefinition(t));
      Context.defineModule(moduleDefinition.modulePath, moduleDefinition.types);
    }
  }

  static function parseInlineHaxe(code:String, position:Position):Expr return
  {
    #if macro
      Context.parseInlineString(code, position);
    #else
      throw "TODO: 不在宏中时，应使用 https://github.com/Simn/haxeparser";
    #end
  }

  static function parseHaxe(code:String, position:Position):Expr return
  {
    #if macro
      Context.parse(code, position);
    #else
      throw "TODO: 不在宏中时，应使用 https://github.com/Simn/haxeparser";
    #end
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


  static function commentBuilder(cell:CsvCell, isDefaultItem:Bool, fieldOutput:Array<Field>):Void
  {
    // 配置表中的这一列是注释，不生成代码。
  }

  public static function buildModuleDefinitions(csvEntries:Iterable <
    {
      var fileName(default, never):String;
      var pack(default, never):Array<String>;
      var workbookName(default, never):String;
      var worksheetName(default, never):String;
      var data(default, never):CsvParser.CsvTable;
    }>):Iterable<
    {
      var modulePath(default, never):String;
      var types(default, never):Array<TypeDefinition>;
    }> return
  {
    var workbookModules = new StringMap<Array<TypeDefinition>>();
    for (csvEntry in csvEntries)
    {
      var csvFileName = csvEntry.fileName;
      var workbookName = csvEntry.workbookName;
      var worksheetName = csvEntry.worksheetName;
      var pack = csvEntry.pack;
      var baseItemClassName = workbookName + "_Item";
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
      var workbookModule = if (workbookModules.exists(fullModuleName))
      {
        workbookModules.get(fullModuleName);
      }
      else
      {
        var workbookModule:Array<TypeDefinition> = [];
        workbookModule.push(
        {
          name: workbookName,
          pack: pack,
          pos: PositionTools.here(),
          kind: TDClass(),
          fields: [],
        });
        workbookModule.push(
        {
          name: baseItemClassName,
          pack: pack,
          pos: PositionTools.here(),
          kind: TDClass(),
          meta:
          [
            {
              name: ":allow",
              params: [ moduleExpr ],
              pos: PositionTools.here(),
            }
          ],
          fields:
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
          ],
        });
        workbookModules.set(fullModuleName, workbookModule);
        workbookModule;
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

      var typeDefinition = null;
      var csvData = csvEntry.data;
      var headRow = csvData[0];
      var numColumnsRequired = headRow.length;
      var fieldBuilders = [];
      for (x in 2...numColumnsRequired)
      {
        var headCell = headRow[x];
        var sourceField = parseHead(headCell.content, csvFileName, headCell.positionMin, headCell.positionMax);
        if (sourceField == null)
        {
          fieldBuilders[x - 2] = commentBuilder;
        }
        else
        {
          fieldBuilders[x - 2] = function(cell:CsvCell, isDefaultItem:Bool, fieldOutput:Array<Field>):Void
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
                if (!isDefaultItem)
                {
                  newAccess.push(AOverride);
                }
                if (!originalAccess.exists(function(a) return a.match(APrivate)))
                {
                  newAccess.push(APublic);
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
              case FFun( { expr: null, args: args, ret: ret, params: null } ):
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
                      access: newAccess,
                      pos: sourceField.pos,
                      meta: sourceField.meta.concat([ { pos: sourceField.pos, name: ":protected" } ]),
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
                    access: newAccess,
                    pos: sourceField.pos,
                    meta: sourceField.meta.concat(
                      [
                        {
                          pos: sourceField.pos,
                          name: ":native",
                          params: [ { pos: sourceField.pos, expr: EConst(CString(fieldName)),  } ],
                        }
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
      function buildItemDefinition(row:Null<CsvRow>):Null<TypeDefinition> return
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
        var classMeta = [];
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
          return null;
        }
        var isDefaultItem = itemId == worksheetName;
        if (isDefaultItem)
        {
          hasCustomBaseClass = true;
        }

        var cell1 = getCell(1); //  TODO: 参数

        var fields = [];
        for (i in 0...fieldBuilders.length)
        {
          var x = i + 2;
          fieldBuilders[i](getCell(x), isDefaultItem, fields);
        }
        var pos0 = getPosition(cell0);
        if (isDefaultItem)
        {
          classMeta.push({ name: ":bridgeProperties", pos: pos0 });
        }
        {
          pack: pack,
          name: itemId,
          pos: pos0,
          meta: classMeta,
          kind: TDClass(
            {
              pack: pack,
              name: workbookName,
              sub: isDefaultItem ? baseItemClassName : worksheetName,
            }),
          fields: fields,
        }
      }

      for (y in 1...csvData.length)
      {
        switch (buildItemDefinition(csvData[y]))
        {
          case null: // 被忽略的注释行
          case itemDefinition:
          {
            workbookModule.push(itemDefinition);
          }
        }
      }

      if (!hasCustomBaseClass)
      {
        workbookModule.push(buildItemDefinition(null));
      }
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
