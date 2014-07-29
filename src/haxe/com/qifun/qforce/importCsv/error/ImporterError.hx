package com.qifun.qforce.importCsv.error ;

import com.qifun.locale.Translator;

class ImporterError
{
  public var min:Int;
  public var max:Int;
  public var file:String;

  @:allow(com.qifun.qforce.importCsv)
  function new(min:Int, max:Int, file:String)
  {
    this.min = min;
    this.max = max;
    this.file = file;
  }

  public var message(get, never):String;

  function get_message() return "Import parsed CSV failed";

}

class UnexpectedVarInitializer extends ImporterError
{

  override function get_message() return
  {
    Translator.translate("The var definition in first row must not include a initializer");
  }

}

class UnexpectedAccess extends ImporterError
{

  override function get_message() return
  {
    Translator.translate("Unexpected access");
  }

}

class UnexpectedFunctionBody extends ImporterError
{

  override function get_message() return
  {
    Translator.translate("The function definition in first row must not include a function body");
  }

}

class PropertyIsNotSupported extends ImporterError
{

  override function get_message() return Translator.translate("Property is not supported");

}

class ExpectField extends ImporterError
{

  override function get_message() return Translator.translate("Expected `function` or `var`");

}

class ExpectStringLiteral extends ImporterError
{

  override function get_message() return Translator.translate("Expected \"");

}

class ExpectVar extends ImporterError
{

  override function get_message() return Translator.translate("Expected `var`");

}

@:final
class ExpectMetaOrItemId extends ImporterError
{

  override function get_message() return Translator.translate("Expected `@meta` or `ItemId`");

}

class InvalidCsvFileName extends ImporterError
{

  override function get_message() return
  {
    Translator.translate("The file name should match *.*.utf-8.csv!");
  }

}

