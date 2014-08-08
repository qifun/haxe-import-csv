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

class ExpectTypePath extends ImporterError
{

  override function get_message() return Translator.translate("Expected TypePath");

}

class ExpectImportExpr extends ImporterError
{

  override function get_message() return Translator.translate("Expected ImportExpr");

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


