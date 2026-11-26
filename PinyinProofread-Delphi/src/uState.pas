unit uState;

interface

uses
  System.Classes, System.SysUtils, Vcl.StdCtrls, Vcl.Graphics;

type
  TStringMatrix = array of array of string;
  TBoolMatrix = array of array of Boolean;

var
  // 表格逻辑尺寸（以“字”为单位，一个字占两行：上拼音、下汉字）
  NRow: Integer = 8;
  NCol: Integer = 18;

  // 由字体度量得到的像素尺寸
  CharacterSize: Integer = 65;
  PinyinSize: Integer = 25;
  ColumnWidth: Integer = 40;
  ScreenWidth: Integer = 0;
  ScreenHeight: Integer = 0;

  // 逻辑数据（NRow x NCol）
  Characters: TStringMatrix;
  Pinyins: TStringMatrix;
  CellEditable: TBoolMatrix;

  // JTable 的二维显示模型（2*NRow x NCol）：偶数行拼音、奇数行汉字
  Contents: TStringMatrix;

  // 突出字符集（对应 Java 的 TreeSet<String>）
  Alerts: TStringList;
  AlertColor: TColor = clRed;

  // 字体对象（等价于 Main.character_font / Main.pinyin_font）
  CharacterFont: TFont;
  PinyinFont: TFont;
  CharacterFontName: string = 'PMingLiU';
  PinyinFontName: string = 'GB Pinyinok-C';

  // 供 FileProcessor 更新页码标签（等价于 Main.current_page / Main.total_pages）
  LblCurrentPage: TLabel;
  LblTotalPages: TLabel;

  // 供播放线程回调主窗体（解耦，避免单元循环引用）
  PlayTick: procedure of object;      // 每次朗读前高亮当前单元格
  PlayNextPage: procedure of object;  // 播放到页尾时翻页
  PlayStartRow: Integer = 0;          // 播放起始单元格（网格行号）
  PlayStartCol: Integer = 0;
  PlayCurRow: Integer = 0;            // 当前朗读的逻辑行（供高亮）
  PlayCurCol: Integer = 0;
  PlayHighlight: Boolean = False;      // 播放高亮开关：播放中 True，暂停/停止/关闭 False
  PlayHighlightColor: TColor = clYellow; // 当前朗读单元格的高亮背景色

function IsAlert(const S: string): Boolean;
procedure RenewContents; // 逻辑数据 -> JTable 显示模型
procedure PullContents;  // JTable 显示模型 -> 逻辑数据

implementation

function IsAlert(const S: string): Boolean;
begin
  Result := (S <> '') and Assigned(Alerts) and (Alerts.IndexOf(S) >= 0);
end;

procedure RenewContents;
var
  I, J: Integer;
begin
  for I := 0 to NRow - 1 do
    for J := 0 to NCol - 1 do
    begin
      Contents[2 * I, J] := Pinyins[I][J];
      Contents[2 * I + 1, J] := Characters[I][J];
    end;
end;

procedure PullContents;
var
  I, J: Integer;
begin
  for I := 0 to NRow - 1 do
    for J := 0 to NCol - 1 do
    begin
      Pinyins[I][J] := Contents[2 * I, J];
      Characters[I][J] := Contents[2 * I + 1, J];
    end;
end;

end.
