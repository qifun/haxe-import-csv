package com.qifun.qforce.importCsv;
import haxe.macro.Expr;
import haxe.macro.*;

@:nativeGen
@:autoBuild(com.qifun.qforce.importCsv.IImportedRow.ImportedRowBuilder.build())
interface IImportedRow
{

}

#if macro
class ImportedRowBuilder
{

  public static function build():Array<Field> return
  {
    // TODO: 创建equals和hashCode函数
    Context.getBuildFields();
  }

}
#end
