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
import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.MacroStringTools;

@:nativeGen
@:autoBuild(com.qifun.qforce.importCsv.ImportedRow.ImportedRowBuilder.build())
class ImportedRow
#if java
extends java.lang.Object implements java.internal.IEquatable
#elseif cs
extends cs.system.Object
#end
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

  macro public static function build():Array<Field> return
  {
    // TODO: 创建toString、equals和hashCode函数
    var fields = Context.getBuildFields();
    var classType = Context.getLocalClass().get();
    var isWorkSheetRow:Bool = false;
    for (metaDate in classType.meta.get())
    {
      if (metaDate.name == ":worksheetRow")
      {
        isWorkSheetRow = true;
        break;
      }
    }
    if (!isWorkSheetRow)
      return fields;
    
    var toStringDefExpr = macro function():String return $ { toStringExprMaker() };
    if (Context.defined("java"))
    {
      fields.push( {
        name: "toString",
        doc: null,
        meta: [{ name: ":overload", pos: Context.currentPos() }],
        access: [APublic, AOverride],
        kind: FFun(switch(toStringDefExpr.expr) {
          case EFunction(_, f):f;
          default: throw "Unreachable code!";
        }),
        pos: Context.currentPos() 
      });
    }
    else if (Context.defined("cs"))
    {
        fields.push( {
        name: "ToString",
        doc: null,
        meta: [{ name: ":overload", pos: Context.currentPos() }],
        access: [APublic],
        kind: FFun(switch(toStringDefExpr.expr) {
          case EFunction(_, f):f;
          default: throw "Unreachable code!";
        }),
        pos: Context.currentPos() 
      });
    }
    var hashCodeExpr:Expr;
    if (haxe.macro.Context.defined("java"))
    {
      hashCodeExpr = macro function():Int
      {
        var str = toString();
        var hash = str.length;
        var i = -1;
        while (++i < str.length)
        {
          hash = (hash << 5) ^ (hash >> 27) ^ str.charCodeAt(i) ;
        }
        return hash;
      }
    }
    else if (haxe.macro.Context.defined("cs"))
    {
      hashCodeExpr = macro function():Int
      {
        var str = ToString();
        var hash = str.length;
        var i = -1;
        while (++i < str.length)
        {
          hash = (hash << 5) ^ (hash >> 27) ^ str.charCodeAt(i) ;
        }
        return hash;
      }
    }
    
    if (Context.defined("java"))
    {
      fields.push( {
        name: "hashCode",
        doc: null,
        meta: [{ name: ":overload", pos: Context.currentPos() }],
        access: [APublic, AOverride],
        kind: FFun(switch(hashCodeExpr.expr) {
          case EFunction(_, f):f;
          default: throw "Unreachable code!";
        }),
        pos: Context.currentPos()
      });
    }
    else if (Context.defined("cs"))
    {
        fields.push( {
        name: "GetHashCode",
        doc: null,
        meta: [],
        access: [APublic],
        kind: FFun(switch(hashCodeExpr.expr) {
          case EFunction(_, f):f;
          default: throw "Unreachable code!";
        }),
        pos: Context.currentPos()
      });
    }
    var equalsExpr = equalsExprMaker();
    
    if (Context.defined("java"))
    {
      fields.push( {
        name: "equals",
        doc: null,
        meta: [{ name: ":overload", pos: Context.currentPos() }],
        access: [APublic, AOverride],
        kind: FFun(switch(equalsExpr.expr) {
          case EFunction(_, f):f;
          default: throw "Unreachable code!";
        }),
        pos: Context.currentPos()
      });
    }
    else if (Context.defined("cs"))
    {
      fields.push( {
        name: "Equals",
        doc: null,
        meta: [],
        access: [APublic],
        kind: FFun(switch(equalsExpr.expr) {
          case EFunction(_, f):f;
          default: throw "Unreachable code!";
        }),
        pos: Context.currentPos()
      });
    }
    
    fields;
  }
  
  private static inline function equalsExprMaker():Expr return
  {
    var fields = Context.getBuildFields();
    var classPackPath = Context.getLocalClass().get().pack.copy();
    classPackPath.push(Context.getLocalClass().get().name);
    var classPathExpr = MacroStringTools.toFieldExpr(classPackPath);
    var compareExpr:Expr = macro true;
    
    for (field in fields) 
    {
      if (field.name == "new")
      {
        var constructFunction = switch(field.kind)
        {
          case FFun(f):
          {
            f;
          }
          default: 
          {
            throw "Unreachable code!";
          }
        }
        
        var isFirst:Bool = true;
        if (Context.defined("java"))
        {
          for (arg in constructFunction.args)
          {
            var fieldName = arg.name;
            if (isFirst)
            {
              compareExpr = macro ($i { fieldName} == o.$fieldName );
              isFirst = false;
            }
            else
            {
              compareExpr = macro $compareExpr && ($i { fieldName} == o.$fieldName );
            }
          }  
        }
        else if(Context.defined("cs"))
        {
          for (arg in constructFunction.args)
          {
            var fieldName = arg.name;
            if (isFirst)
            {
              compareExpr = macro cs.internal.Runtime.eq($i { fieldName} , o.$fieldName );
              isFirst = false;
            }
            else
            {
              compareExpr = macro $compareExpr && cs.internal.Runtime.eq($i { fieldName} , o.$fieldName );
            }
          }  
        }
        break;
      }
    }
    
    var equalsExpr = macro function(other:Dynamic):Bool return
    {
      var o = Std.instance((other), $classPathExpr);
      if (o == null)
      {
        return false;
      }
      else
      {
        return $compareExpr;
      }
    }
    
    equalsExpr;
  }
  
  private static inline function toStringExprMaker():Expr return
  {
    var fields = Context.getBuildFields();
    var toStringExprBuilder:Expr = macro $v{Context.getLocalClass().get().name} + "(";
    
    for (field in fields) 
    {
      if (field.name == "new")
      {
        var constructFunction = switch(field.kind)
        {
          case FFun(f):
          {
            f;
          }
          default: 
          {
            throw "Unreachable code!";
          }
        }
        
        var isFirst:Bool = true;
        for (arg in constructFunction.args)
        {
          if (isFirst)
          {
            toStringExprBuilder = macro $toStringExprBuilder + $v {arg.name} + "(" + Std.string( $i { arg.name } ) + ")";
            isFirst = false;
          }
          else
          {
            toStringExprBuilder = macro $toStringExprBuilder + ", " + $v {arg.name} + "(" + Std.string( $i { arg.name } ) + ")";
          }
        }  
        break;
      }
    }
    macro $toStringExprBuilder + ")";
  }
  
}
#end

