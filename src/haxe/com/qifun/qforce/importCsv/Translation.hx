package com.qifun.qforce.importCsv;
import haxe.macro.*;

class Translation
{

  static var STRING_MAPPING(default, never) =
  [
    "zh_CN.GBK" =>
    [
      "Unexpected access" =>
        "不支持的修饰符",
      "Expect a string literal" =>
        "需要字符串字面量",
      "Expected `@meta` or `ItemId`" =>
        "需要`@meta`或`ItemId`",
      "Expected `function` or `var`" =>
        "需要`function`或`var`",
      "Property is not supported" =>
        "不支持属性",
      "The function definition in first row must not include a function body" =>
        "表格第一行中的函数定义不得包含函数体",
      "The var definition in first row must not include a initializer" =>
        "表格第一行中的变量定义不得包含初始值",
    ]
  ];

  macro public static function translate(self:ExprOf<String>):ExprOf<String> return
  {
    switch (self)
    {
      case { expr: EConst(CString(origin)) }:
      {
        var locale = Context.definedValue("locale");
        if (locale == null)
        {
          self;
        }
        else
        {
          var mapping = STRING_MAPPING.get(locale);
          if (mapping == null)
          {
            self;
          }
          else
          {
            var translated = mapping.get(origin);
            if (translated == null)
            {
              self;
            }
            else
            {
              if (MacroStringTools.isFormatExpr(self))
              {
                MacroStringTools.formatString(translated, Context.currentPos());
              }
              else
              {
                Context.makeExpr(translated, Context.currentPos());
              }
            }
          }
        }
      }
      case { pos: p }:
      {
        Context.error(translate("Expect a string literal"), p);
      }
    }
  }

}
