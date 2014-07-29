package com.qifun.qforce.importCsv;

import com.qifun.locale.Translator;
import haxe.macro.*;

abstract StringInterpolation(String)
{

  public inline function new(underlying:String)
  {
    this = underlying;
  }

  macro public static function parseCell(cellContent:ExprOf<String>):Expr return
  {
    switch (cellContent)
    {
      case { pos: PositionTools.getInfos(_) => p, expr: EConst(CString(code)) }:
      {
        var stringExpr = MacroStringTools.formatString(code, PositionTools.make(
          {
            min: p.min - 1,
            max: p.max,
            file: p.file,
          }));
        macro new com.qifun.qforce.importCsv.StringInterpolation($stringExpr);
      }
      case { pos: pos } :
      {
        Context.error(Translator.translate("Expected \""), pos);
      }
    }
  }

}
