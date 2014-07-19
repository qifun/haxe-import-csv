package com.qifun.qforce.importCsv ;

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
import sys.FileSystem;
import sys.io.File;
import sys.io.FileInput;
using StringTools;


@:final
private class WorkbookModule
{
  public function new() { }
  public var mainTypeDefinition:TypeDefinition;
  public var itemTypeDefinition:TypeDefinition;
  public var otherTypeDefinitions:Array<TypeDefinition>;
}

@:final
private class ExpectMetaOrItemId extends ImporterError
{

  override function get_message() return "Expected `@meta` or `ItemId`";

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
    #if macro
    // Workaround for https://github.com/HaxeFoundation/haxe/issues/3188
    this.file = sys.FileSystem.fullPath(file);
    #else
    this.file = file;
    #end
  }

  public var message(get, never):String;

  function get_message() return "Import parsed CSV failed";

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
        var input = File.read(resolvedPath);
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
      //Context.error(
			//"xxx",
			//Context.makePosition(
				//{
					////file: "src/test-haxe/com/qifun/qforce/importCsv/TestConfig.xlsx.Sheet1.utf-8.csv",
          ////file: "D:\\Documents\\xlsx-to-sample\\haxe-import-csv\\src\\test-haxe\\com\\qifun\\qforce\\importCsv\\TestConfig.xlsx.Sheet1.utf-8.csv",
					////file: "D:/Documents/xlsx-to-sample/haxe-import-csv/src/test-haxe/com/qifun/qforce/importCsv/TestConfig.xlsx.Sheet1.utf-8.csv",
					////file: "src/../src/test-haxe/com/qifun/qforce/importCsv/TestConfig.xlsx.Sheet1.utf-8.csv",
					//min: 93,
					//max: 101,
				//}));
      //trace(PositionTools.getInfos(e.position));
      Context.error(e.message, PositionTools.make(e));
    }

    for (moduleDefinition in moduleDefinitions)
    {
      Context.defineModule(moduleDefinition.modulePath, moduleDefinition.types);
    }
  }

  static function parseHaxe(code:String, position:Position):Expr return
  {
    #if macro
      Context.parseInlineString(code, position);
    #else
      throw "TODO: 不在宏中时，应使用 https://github.com/Simn/haxeparser";
    #end
  }

  static function parseItemId(
    content:String,
    fileName:String,
    positionMin:Int,
    positionMax:Int,
    classMeta:Metadata):Null<String> return
  {
    var itemIdCodeSuffix = "\n-importCsvPlaceholder";
    var expr0 = parseHaxe('${content}$itemIdCodeSuffix', PositionTools.make(
      {
        min: positionMin,
        max: positionMax,
        file: fileName,
      }));
    function parseItemIdExpr(expr0:Expr):String return
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
          parseItemIdExpr(e);
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
      case { pos: _, expr: EBinop(Binop.OpSub, idOrMeta, { pos: _, expr: EConst(CIdent("importCsvPlaceholder")) } ) }:
      {
        parseItemIdExpr(idOrMeta);
      }
      case { pos: _, expr: EUnop(Unop.OpNeg, false, { pos: _, expr: EConst(CIdent("importCsvPlaceholder")) } ) }:
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
    var workbookModules = new StringMap<WorkbookModule>();
    for (csvEntry in csvEntries)
    {
      var workbookName = csvEntry.workbookName;
      var worksheetName = csvEntry.worksheetName;
      var pack = csvEntry.pack;
      var itemClassName = workbookName + "_Item";
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
        var workbookModule = new WorkbookModule();
        workbookModule.otherTypeDefinitions = [];
        workbookModule.mainTypeDefinition =
        {
          name: workbookName,
          pack: pack,
          pos: ExprTools.makeMacroPosition(),
          kind: TDClass(),
          fields: [],
        }
        workbookModule.itemTypeDefinition =
        {
          name: itemClassName,
          pack: pack,
          pos: ExprTools.makeMacroPosition(),
          kind: TDClass(),
          meta:
          [
            {
              name: ":allow",
              params: [ moduleExpr ],
              pos: ExprTools.makeMacroPosition(),
            }
          ],
          fields:
          [
            {
              name: "new",
              pos: ExprTools.makeMacroPosition(),
              access: [ APrivate, AInline ],
              kind: FFun(
                {
                  args: [],
                  ret: null,
                  expr: macro null,
                }),
            }
          ],
        }
        workbookModules.set(fullModuleName, workbookModule);
        workbookModule;
      }

      workbookModule.otherTypeDefinitions.push(
        {
          name: worksheetName,
          pack: pack,
          pos: ExprTools.makeMacroPosition(),
          kind: TDClass(
            {
              name: workbookName,
              pack: pack,
              sub: itemClassName,
            }),
          fields:
          [

          ]
        });

      var typeDefinition = null;
      var csvData = csvEntry.data;
      var headRow = csvData[0];
      var numColumnsRequired = headRow.length;

      for (y in 1...csvData.length)
      {
        var row = csvData[y];
        var numColumns = row.length;
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
              positionMin: row[numColumns - 1].positionMax,
              positionMax: row[numColumns - 1].positionMax,
            }
          }
        }
        var cell1 = getCell(1);
        var classMeta = [];
        var cell0 = getCell(0);
        var itemId = parseItemId(cell0.content, csvEntry.fileName, cell0.positionMin, cell0.positionMax, classMeta);
      }

      //Context.makePosition(
      trace(parseHaxe("//\n-1", ExprTools.makeMacroPosition()));

      //trace(parseHaxe("@xx @xx importCsvPlaceholder", ExprTools.makeMacroPosition()));
      //parseHaxe("var importCsvPlaceholder:{ a:Int }", ExprTools.makeMacroPosition());
      //parseHaxe("var importCsvPlaceholder:{ \nfunction1 a():Int\n }", ExprTools.makeMacroPosition());
      // TODO，把工作表加入
    }


    [
      for (fullModuleName in workbookModules.keys())
      {
        var workbookModule = workbookModules.get(fullModuleName);
        {
          modulePath: fullModuleName,
          types: workbookModule.otherTypeDefinitions.concat(
            [
              workbookModule.itemTypeDefinition,
              workbookModule.mainTypeDefinition,
            ]),
        }
      }
    ];
  }

}
