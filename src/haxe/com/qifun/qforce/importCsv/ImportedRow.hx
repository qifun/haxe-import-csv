package com.qifun.qforce.importCsv;
import haxe.macro.Expr;
import haxe.macro.*;

@:nativeGen
@:autoBuild(com.qifun.qforce.importCsv.ImportedRow.ImportedRowBuilder.build())
class ImportedRow
{

  var y(get, never):Bool;

  @:protected
  inline function get_y() return true;

  var n(get, never):Bool;

  @:protected
  inline function get_n() return false;


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
