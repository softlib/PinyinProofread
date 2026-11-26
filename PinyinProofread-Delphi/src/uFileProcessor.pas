unit uFileProcessor;

interface

/// <summary>
/// 对应 Java 的 FileProcessor 类。
/// 负责把 HTML 中的 <ruby>字<rt>拼音</rt></ruby> 解析成块、分页、回写。
/// </summary>

type
  TBlock = class
  public
    Visible: Boolean;
    Content: string;
    Character: string;
    Pinyin: string;
    constructor Create(const AContent: string);
    function ToText: string;
  end;

  TBlockMatrix = array of array of TBlock;

procedure Clear;
function Load: Boolean;
function Save: Boolean;
procedure PreviousPage;
procedure NextPage;

procedure PushUp;
procedure PullBack;

function GetNextRowIndex(ARowIndex, AColIndex, ANRow, ANCol: Integer): Integer;
function GetNextColumnIndex(ARowIndex, AColIndex, ANRow, ANCol: Integer): Integer;
function GetCurrentPageBlock(ARow, ACol: Integer): TBlock;

var
  Filename: string;
  CurrentPageIndex: Integer = 0;

implementation

uses
  System.Classes, System.SysUtils, System.StrUtils, System.IOUtils,
  System.Generics.Collections,
  uState, uRecord;

type
  TBlockList = System.Generics.Collections.TList<TBlock>;

var
  FileContents: TBlockList;
  Pages: array of TBlockMatrix;
  PageCellEditable: array of array of array of Boolean; // [page][row][col]
  BlankBlock: TBlock = nil; // 共享空白块，生命周期与 Pages 一致

{ TBlock }

constructor TBlock.Create(const AContent: string);
var
  P1, P2, P3: Integer;
begin
  inherited Create;
  Visible := False;
  Content := AContent;
  Character := '';
  Pinyin := '';

  if (Pos('<ruby>', AContent) > 0) and (Pos('<rt>', AContent) > 0) then
  begin
    Visible := True;
    // character = 第一个 <ruby> 之后、<rt> 之前的第一个字符
    P1 := Pos('<ruby>', AContent) + Length('<ruby>');
    P2 := PosEx('<rt>', AContent, P1);
    if P2 > P1 then
      Character := AContent[P1]
    else if P1 <= Length(AContent) then
      Character := AContent[P1];

    // pinyin = <rt> 与 </rt> 之间的内容
    P1 := Pos('<rt>', AContent) + Length('<rt>');
    P2 := PosEx('</rt>', AContent, P1);
    if P2 > P1 then
      Pinyin := Copy(AContent, P1, P2 - P1)
    else
      Pinyin := Copy(AContent, P1, MaxInt);
  end;
end;

function TBlock.ToText: string;
begin
  if Visible then
    Result := '<ruby>' + Character + '<rt>' + Pinyin + '</rt></ruby>'
  else
    Result := Content;
end;

procedure Clear;
var
  I: Integer;
begin
  if Assigned(FileContents) then
  begin
    for I := 0 to FileContents.Count - 1 do
      FileContents[I].Free;
    FileContents.Clear;
  end
  else
    FileContents := TBlockList.Create;

  FreeAndNil(BlankBlock);
  SetLength(Pages, 0);
  SetLength(PageCellEditable, 0);
  CurrentPageIndex := 0;
end;

function GetFileContent: string;
var
  S: string;
begin
  S := TFile.ReadAllText(Filename, TEncoding.UTF8);
  // 与 Java Scanner 一致：统一换行符为 \n
  S := StringReplace(S, #13#10, #10, [rfReplaceAll]);
  S := StringReplace(S, #13, #10, [rfReplaceAll]);
  // 去掉结尾所有 \n
  while (Length(S) > 0) and (S[Length(S)] = #10) do
    SetLength(S, Length(S) - 1);
  Result := S;
end;

procedure ReadFile;
var
  Content: string;
  Pos1, NewPos, P: Integer;
begin
  Content := GetFileContent;
  Pos1 := 1; // Delphi 字符串从 1 开始
  while Pos1 <= Length(Content) do
  begin
    P := PosEx('<ruby>', Content, Pos1);
    if P = Pos1 then
    begin
      P := PosEx('</ruby>', Content, Pos1);
      if P > 0 then
        NewPos := P + Length('</ruby>') - 1
      else
        NewPos := Length(Content);
    end
    else
    begin
      if P > 0 then
        NewPos := P - 1
      else
        NewPos := Length(Content);
    end;

    if NewPos < Pos1 then
      NewPos := Pos1;

    FileContents.Add(TBlock.Create(Copy(Content, Pos1, NewPos - Pos1 + 1)));
    Pos1 := NewPos + 1;
  end;
end;

function GetNextRowIndex(ARowIndex, AColIndex, ANRow, ANCol: Integer): Integer;
begin
  if AColIndex = ANCol - 1 then
    Result := (ARowIndex + 1) mod ANRow
  else
    Result := ARowIndex;
end;

function GetNextColumnIndex(ARowIndex, AColIndex, ANRow, ANCol: Integer): Integer;
begin
  if AColIndex = ANCol - 1 then
    Result := 0
  else
    Result := (AColIndex + 1) mod ANCol;
end;

procedure AddPage(var ACurrent: TBlockMatrix; ANRow, ANCol: Integer);
var
  L: Integer;
begin
  L := Length(Pages);
  SetLength(Pages, L + 1);
  SetLength(Pages[L], ANRow, ANCol);
  ACurrent := Pages[L];
end;

procedure GetPages(ANRow, ANCol: Integer);
var
  RowIdx, ColIdx, I, J, K: Integer;
  Blank: TBlock;
  Current: TBlockMatrix;
  Block: TBlock;
  LastPage: TBlockMatrix;
begin
  SetLength(Pages, 0);
  if BlankBlock = nil then
    BlankBlock := TBlock.Create(''); // 空白块，随 Pages 一起存活
  Blank := BlankBlock;
  RowIdx := 0;
    ColIdx := 0;
    AddPage(Current, ANRow, ANCol);

    for Block in FileContents do
    begin
      if Block.Visible then
      begin
        Current[RowIdx, ColIdx] := Block;
        RowIdx := GetNextRowIndex(RowIdx, ColIdx, ANRow, ANCol);
        ColIdx := GetNextColumnIndex(RowIdx, ColIdx, ANRow, ANCol);
        if (RowIdx = 0) and (ColIdx = 0) then
          AddPage(Current, ANRow, ANCol);
      end
      else if Pos('</p>', Block.Content) > 0 then
      begin
        for I := ColIdx to ANCol - 1 do
       begin
          Current[RowIdx, ColIdx] := Blank;
          RowIdx := GetNextRowIndex(RowIdx, ColIdx, ANRow, ANCol);
          ColIdx := GetNextColumnIndex(RowIdx, ColIdx, ANRow, ANCol);
        end;
        if (RowIdx = 0) and (ColIdx = 0) then
          AddPage(Current, ANRow, ANCol);
      end;
    end;

    LastPage := Pages[High(Pages)];
    if not Assigned(LastPage[0, 0]) then
    begin
      if Length(Pages) = 1 then
      begin
        for I := 0 to ANRow * ANCol - 1 do
        begin
          Current[RowIdx, ColIdx] := Blank;
          RowIdx := GetNextRowIndex(RowIdx, ColIdx, ANRow, ANCol);
          ColIdx := GetNextColumnIndex(RowIdx, ColIdx, ANRow, ANCol);
        end;
      end
      else
        SetLength(Pages, Length(Pages) - 1);
    end
    else
    begin
      while not ((RowIdx = 0) and (ColIdx = 0)) do
      begin
        Current[RowIdx, ColIdx] := Blank;
        RowIdx := GetNextRowIndex(RowIdx, ColIdx, ANRow, ANCol);
        ColIdx := GetNextColumnIndex(RowIdx, ColIdx, ANRow, ANCol);
      end;
    end;

    SetLength(PageCellEditable, Length(Pages));
    for I := 0 to High(Pages) do
    begin
      SetLength(PageCellEditable[I], ANRow, ANCol);
      for J := 0 to ANRow - 1 do
        for K := 0 to ANCol - 1 do
          PageCellEditable[I][J][K] :=
            Assigned(Pages[I][J][K]) and (Pages[I][J][K].Character <> '');
    end;
end;

procedure PushUp;
var
  I, J: Integer;
  Page: TBlockMatrix;
  B: TBlock;
begin
  if Length(Pages) = 0 then
    Exit;
  Page := Pages[CurrentPageIndex];
  for I := 0 to NRow - 1 do
    for J := 0 to NCol - 1 do
    begin
      B := Page[I][J];
      if Assigned(B) then
      begin
        Characters[I][J] := Trim(B.Character);
        Pinyins[I][J] := Trim(B.Pinyin);
      end
      else
      begin
        Characters[I][J] := '';
        Pinyins[I][J] := '';
      end;
      CellEditable[I][J] := PageCellEditable[CurrentPageIndex][I][J];
    end;

  // 同步到 JTable 显示模型
  for I := 0 to NRow - 1 do
    for J := 0 to NCol - 1 do
    begin
      Contents[2 * I, J] := Pinyins[I][J];
      Contents[2 * I + 1, J] := Characters[I][J];
    end;
end;

procedure PullBack;
var
  I, J: Integer;
  Page: TBlockMatrix;
  B: TBlock;
begin
  if Length(Pages) = 0 then
    Exit;
  Page := Pages[CurrentPageIndex];
  for I := 0 to NRow - 1 do
    for J := 0 to NCol - 1 do
    begin
      B := Page[I][J];
      if not Assigned(B) then
        Continue;
      if Characters[I][J] = '' then
        B.Character := ''
      else
        B.Character := Trim(Characters[I][J]);
      if Pinyins[I][J] = '' then
        B.Pinyin := ''
      else
        B.Pinyin := Trim(Pinyins[I][J]);
    end;
end;

function GenerateFileContent: string;
var
  I: Integer;
  SB: TStringBuilder;
begin
  SB := TStringBuilder.Create;
  try
    for I := 0 to FileContents.Count - 1 do
      SB.Append(FileContents[I].ToText);
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function Save: Boolean;
var
  Bytes: TBytes;
  Stream: TFileStream;
  Text: string;
begin
  Result := False;
  try
    PullBack;
    Text := GenerateFileContent;
    Bytes := TEncoding.UTF8.GetBytes(Text); // 不含 BOM，与 Java PrintWriter(UTF_8) 一致
    Stream := TFileStream.Create(Filename, fmCreate);
    try
      if Length(Bytes) > 0 then
        Stream.WriteBuffer(Bytes[0], Length(Bytes));
    finally
      Stream.Free;
    end;
    Result := True;
  except
    on E: Exception do
    begin
      Result := False;
    end;
  end;
end;

function Load: Boolean;
var
  MaxIdx: Integer;
begin
  Result := False;
  Clear;
  try
    ReadFile;
    GetPages(NRow, NCol);
    if Length(Pages) = 0 then
      Exit;

    MaxIdx := uRecord.Get(Filename);
    if MaxIdx < 0 then
      MaxIdx := 0;
    if MaxIdx > High(Pages) then
      MaxIdx := High(Pages);
    CurrentPageIndex := MaxIdx;

    PushUp;
    if Assigned(LblCurrentPage) then
      LblCurrentPage.Caption := IntToStr(CurrentPageIndex + 1);
    if Assigned(LblTotalPages) then
      LblTotalPages.Caption := IntToStr(Length(Pages));
    Result := True;
  except
    on E: Exception do
      Result := False;
  end;
end;

procedure PreviousPage;
begin
  PullBack;
  if CurrentPageIndex > 0 then
  begin
    Dec(CurrentPageIndex);
    if Assigned(LblCurrentPage) then
      LblCurrentPage.Caption := IntToStr(CurrentPageIndex + 1);
  end;
  uRecord.Add(Filename, CurrentPageIndex);
  PushUp;
end;

procedure NextPage;
begin
  PullBack;
  if CurrentPageIndex < High(Pages) then
  begin
    Inc(CurrentPageIndex);
    if Assigned(LblCurrentPage) then
      LblCurrentPage.Caption := IntToStr(CurrentPageIndex + 1);
  end;
  uRecord.Add(Filename, CurrentPageIndex);
  PushUp;
end;

function GetCurrentPageBlock(ARow, ACol: Integer): TBlock;
begin
  Result := nil;
  if (Length(Pages) = 0) or (ARow < 0) or (ARow >= NRow) or
     (ACol < 0) or (ACol >= NCol) then
    Exit;
  if CurrentPageIndex > High(Pages) then
    Exit;
  Result := Pages[CurrentPageIndex][ARow, ACol];
end;

end.
