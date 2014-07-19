package com.qifun.qforce.importCsv;
import haxe.io.BytesOutput;
import haxe.io.Eof;
import haxe.io.Input;
import haxe.io.StringInput;

typedef CsvCell =
{
  content: String,
  positionMin: Int,
  positionMax: Int,
}
typedef CsvRow = Array<CsvCell>;

typedef CsvTable = Array<CsvRow>;

private typedef RowFsm = ISource->Array<CsvCell>->RowFsm;

private enum CsvToken
{
  CELL(content:String, positionMin:Int, positionMax:Int);
  CRLF;
  COMMA;
  EOF;
}

class CsvParserError
{

  @:allow(com.qifun.qforce.importCsv.CsvParser)
  function new(positionMin:Int, positionMax:Int)
  {
    this.positionMin = positionMin;
    this.positionMax = positionMax;
  }

  public var positionMin(default, null):Int;

  public var positionMax(default, null):Int;

  public var message(get, never):String;

  function get_message() return "CSV parser error";

}

@:final
private class UnexpectedEof extends CsvParserError
{

  override function get_message() return "Unexpected <end of file>";

}

@:final
private class UnexpectedCell extends CsvParserError
{

  override function get_message() return "Expected CRLF or \",\"";

}

class CsvParser
{

  static function nextToken(input:ISource):CsvToken return
  {
    switch (input.current)
    {
      case -1: EOF;
      case ",".code:
      {
        input.next();
        COMMA;
      }
      case "\n".code:
      {
        // 兼容 LF 换行
        input.next();
        CRLF;
      }
      case "\r".code:
      {
        input.next();
        if (input.current == "\n".code)
        {
          // 标准的 CRLF 换行
          input.next();
          CRLF;
        }
        else
        {
          // 兼容 CR 换行
          CRLF;
        }
      }
      case "\"".code:
      {
        var positionMin = input.position;
        var output = new BytesOutput();
        while (true)
        {
          input.next();
          switch (input.current)
          {
            case "\"".code:
            {
              input.next();
              if (input.current == "\"".code)
              {
                output.writeByte("\"".code);
              }
              else
              {
                return CELL(output.getBytes().toString(), positionMin, input.position);
              }
            }
            case -1:
            {
              throw new UnexpectedEof(input.position, input.position);
            }
            case b:
            {
              output.writeByte(b);
            }
          }
        }
        throw "Unreachable code!";

      }
      case b:
      {
        var positionMin = input.position;
        var output = new BytesOutput();
        output.writeByte(b);
        while (true)
        {
          input.next();
          switch (input.current)
          {
            case "\n".code, "\r".code, ",".code, -1:
            {
              return CELL(output.getBytes().toString(), positionMin, input.position);
            }
            case b:
            {
              output.writeByte(b);
            }
          }
        }
        throw "Unreachable code!";
      }
    }
  }

  static function readComma(input:ISource, rowBuffer:Array<CsvCell>):RowFsm return
  {
    switch (nextToken(input))
    {
      case EOF, CRLF:
      {
        null;
      }
      case CELL(content, positionMin, positionMax):
      {
        throw new UnexpectedCell(positionMin, positionMax);
      }
      case COMMA:
      {
        readCell;
      }
    }
  }

  static function readCell(input:ISource, rowBuffer:Array<CsvCell>):RowFsm return
  {
    switch (nextToken(input))
    {
      case EOF:
      {
        rowBuffer.push({ content: "", positionMin: input.position, positionMax: input.position });
        null;
      }
      case CELL(content, positionMin, positionMax):
      {
        rowBuffer.push({ content: content, positionMin: positionMin, positionMax: positionMax });
        readComma;
      }
      case COMMA:
      {
        rowBuffer.push({ content: "", positionMin: input.position, positionMax: input.position });
        readCell;
      }
      case CRLF:
      {
        rowBuffer.push({ content: "", positionMin: input.position, positionMax: input.position });
        null;
      }
    }

  }

  static function readFirstCell(input:ISource, rowBuffer:Array<CsvCell>):RowFsm return
  {
    switch (nextToken(input))
    {
      case EOF:
      {
        throw new Eof();
      }
      case CELL(content, positionMin, positionMax):
      {
        rowBuffer.push( { content: content, positionMin: positionMin, positionMax: positionMax } );
        readComma;
      }
      case COMMA:
      {
        rowBuffer.push({ content: "", positionMin: input.position, positionMax: input.position });
        readCell;
      }
      case CRLF:
      {
        rowBuffer.push({ content: "", positionMin: input.position, positionMax: input.position });
        null;
      }
    }
  }

  /**
    @throws haxe.io.Eof 什么都没读到，文件就结束了。
  **/
  static function parseRow(input:ISource):CsvRow return
  {

    var result = [];

    var tailrec:RowFsm = readFirstCell(input, result);
    while (tailrec != null)
    {
      tailrec = tailrec(input, result);
    }
    result;
  }

  static function parse(input:ISource):CsvTable return
  {
    var result:CsvTable = [];
    while (true)
    {
      result.push(try parseRow(input) catch (e:Eof) return result);
    }
    throw "Unreachable code!";
  }

  public static function parseString(string:String):CsvTable return
  {
    parse(new StringSource(string));
  }

  public static function parseInput(input:Input):CsvTable return
  {
    parse(new InputSource(input));
  }

}

private interface ISource
{
  function next():Void;

  private function get_current():Int;

  var current(get, never):Int;

  private function get_position():Int;

  var position(get, never):Int;
}

@:final
private class StringSource extends StringInput implements ISource
{
  var head:Int;
  public function next():Void
  {
    try
    {
      head = readByte();
    }
    catch(e:Eof)
    {
      head = -1;
    }
  }

  function get_current():Int
  {
    return head;
  }

  public var current(get, never):Int;

  public function new(s:String)
  {
    super(s);
    head = readByte();
  }

}

@:final
private class InputSource implements ISource
{

  var head:Int;

  var tail:Input;

  public function next():Void
  {
    try
    {
      head = tail.readByte();
      _position++;
    }
    catch(e:Eof)
    {
      head = -1;
    }
  }

  function get_current():Int
  {
    return head;
  }

  public var current(get, never):Int;

  public function new(input:Input)
  {
    head = input.readByte();
    tail = input;
  }

  var _position:Int = 0;

  function get_position():Int return _position;

  public var position(get, never):Int;

}
