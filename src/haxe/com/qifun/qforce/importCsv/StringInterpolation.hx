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

