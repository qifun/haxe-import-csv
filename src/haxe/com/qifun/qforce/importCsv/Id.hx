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
import haxe.macro.Type;
import haxe.macro.Expr;


@:parseCellFunction(com.qifun.qforce.importCsv.Id.IdCellParser.parseCell)
typedef Id<Worksheet> = Worksheet;

class IdCellParser
{

  macro public static function parseCell(cellContent:ExprOf<String>):Expr return
  {
    switch (cellContent)
    {
      case { pos: pos, expr: EConst(CString(code)) }:
      {
        switch (Context.follow(Context.getExpectedType()))
        {
          case TInst(_.get() => { pack: workbookPack, name: worksheetName, module: workbookName}, []):
          {
            var workbookExpr = MacroStringTools.toFieldExpr(workbookName.split("."));
            var expr =
              #if macro
                Context.parse(code+"\n", pos);
              #else
                var p = PositionTools.getInfos(pos);
                var parser = new haxeparser.HaxeParser(byte.ByteData.ofString(code), p.file);
                parser.expr();
              #end
            expr.expr = switch (expr.expr)
            {
              case EConst(CIdent(id)):
              {
                EField(macro ($workbookExpr), id);
              }
              case ECall({ pos: idPos, expr: EConst(CIdent(id)) }, params):
              {
                ECall( { pos: idPos, expr: EField(macro ($workbookExpr), id) }, params);
              }
              default:
              {
                Context.error(Translator.translate("Expect identify"), pos);
              }
            }
            expr;
          }
          default:
          {
            Context.error(Translator.translate("Expect worksheet"), pos);
          }
        }
      }
      case { pos: pos } :
      {
        Context.error(Translator.translate("Expected \""), pos);
      }
    }
  }

}

