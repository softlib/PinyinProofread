unit uRecord;

interface

/// <summary>
/// 对应 Java 的 Record 类：把「文件路径 -> 阅读页码」持久化到 records.txt。
/// Java 使用 TreeMap<String,Integer>，这里用 Sorted 的 TStringList 模拟（按路径排序）。
/// </summary>
procedure ReadRecords;
procedure WriteRecords;
procedure Add(const AFilePath: string; APageIndex: Integer);
function Get(const AFilePath: string): Integer;

implementation

uses
  System.Classes, System.SysUtils;

const
  RECORD_FILE = 'records.txt';
  SEP = '>';

var
  Records: TStringList = nil;

procedure LoadFromFile;
var
  F: TStringList;
  I, P, Idx: Integer;
  Line, Key, Val: string;
begin
  if Records = nil then
    Exit;
  if not FileExists(RECORD_FILE) then
    Exit;

  F := TStringList.Create;
  try
    F.LoadFromFile(RECORD_FILE, TEncoding.UTF8);
    for I := 0 to F.Count - 1 do
    begin
      Line := F[I];
      P := Pos(SEP, Line);
      if P > 0 then
      begin
        Key := Copy(Line, 1, P - 1);
        Val := Copy(Line, P + Length(SEP), MaxInt);
        if (Key <> '') and TryStrToInt(Trim(Val), Idx) then
          if Records.IndexOfName(Key) < 0 then
            Records.Add(Key + SEP + IntToStr(Idx));
      end;
    end;
  finally
    F.Free;
  end;
end;

procedure EnsureLoaded;
begin
  if Records = nil then
  begin
    Records := TStringList.Create;
    Records.Sorted := True;
    Records.Duplicates := dupIgnore;
    Records.NameValueSeparator := SEP;
    LoadFromFile;
  end;
end;

procedure ReadRecords;
begin
  EnsureLoaded;
end;

procedure WriteRecords;
var
  F: TStringList;
  I: Integer;
begin
  if Records = nil then
    Exit;
  F := TStringList.Create;
  try
    for I := 0 to Records.Count - 1 do
      F.Add(Records[I]);
    F.SaveToFile(RECORD_FILE, TEncoding.UTF8);
  finally
    F.Free;
  end;
end;

procedure Add(const AFilePath: string; APageIndex: Integer);
var
  Idx: Integer;
begin
  EnsureLoaded;
  Idx := Records.IndexOfName(AFilePath);
  // Sorted 列表不允许用 Put(Records[Idx] := ...) 修改元素，
  // 否则抛出 "Operation not allowed on a sorted list"。
  // Delete 与 Add 在 Sorted 下均允许：先删旧项再重新加入。
  if Idx >= 0 then
    Records.Delete(Idx);
  Records.Add(AFilePath + SEP + IntToStr(APageIndex));
end;

function Get(const AFilePath: string): Integer;
var
  Idx: Integer;
  V: string;
begin
  EnsureLoaded;
  Idx := Records.IndexOfName(AFilePath);
  if Idx < 0 then
    Exit(0);
  V := Records.ValueFromIndex[Idx];
  if not TryStrToInt(Trim(V), Result) then
    Result := 0;
end;

end.
