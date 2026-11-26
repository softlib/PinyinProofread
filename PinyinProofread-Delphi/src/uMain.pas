unit uMain;

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Classes, System.Math,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  Vcl.ExtCtrls, Vcl.Grids, Vcl.Menus, Vcl.ActnList, Vcl.ComCtrls, Vcl.ExtDlgs;

type
  TMainForm = class(TForm)
  private
    Grid: TStringGrid;
    Editor: TEdit;
    PathEdit: TEdit;
    AlertEdit: TEdit;
    BtnBrowse, BtnOpen, BtnAlert, BtnCancelAlert: TButton;
    BtnPrev, BtnSave, BtnPlay, BtnNext: TButton;
    PanelBottom: TPanel;
    ActionList: TActionList;
    ActPrev, ActNext, ActSave, ActPlay: TAction;
    OpenDialog: TOpenDialog;
    FEditing: Boolean;
    FEditRow, FEditCol: Integer;
    FFontPaths: TStringList;
    procedure BuildUI;
    procedure LoadFonts;
    procedure UnloadFonts;
    procedure MeasureFonts;
    procedure SetupGrid;
    procedure RenewAndRepaint;
    procedure CommitEditor;
    procedure BeginEdit(ACol, ARow: Integer);

    procedure GridDrawCell(Sender: TObject; ACol, ARow: Integer;
      Rect: TRect; State: TGridDrawState);
    procedure GridSelectCell(Sender: TObject; ACol, ARow: Integer;
      var CanSelect: Boolean);
    procedure GridDblClick(Sender: TObject);
    procedure GridKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure EditorKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure EditorExit(Sender: TObject);

    procedure BtnBrowseClick(Sender: TObject);
    procedure BtnOpenClick(Sender: TObject);
    procedure BtnAlertClick(Sender: TObject);
    procedure BtnCancelAlertClick(Sender: TObject);
    procedure ActPrevExecute(Sender: TObject);
    procedure ActNextExecute(Sender: TObject);
    procedure ActSaveExecute(Sender: TObject);
    procedure ActPlayExecute(Sender: TObject);

    procedure PlayTickCallback;
    procedure PlayNextPageCallback;
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  MainForm: TMainForm;

implementation

uses
  uState, uRecord, uFileProcessor, uAudio;

{$R *.dfm}

const
  FR_PRIVATE = $10;

constructor TMainForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner); // 加载最小 DFM，其余控件在 BuildUI 中创建
  BuildUI;
end;

destructor TMainForm.Destroy;
begin
  UnloadFonts;
  inherited Destroy;
end;

procedure TMainForm.LoadFonts;
var
  Base: string;
  Path: string;
begin
  FFontPaths := TStringList.Create;
  Base := ExtractFilePath(ParamStr(0)) + 'res' + PathDelim + 'fonts' + PathDelim;

  Path := Base + CharacterFontName + '.ttf';
  if FileExists(Path) then
  begin
    if AddFontResourceEx(PChar(Path), FR_PRIVATE, nil) > 0 then
      FFontPaths.Add(Path);
  end;

  Path := Base + PinyinFontName + '.ttf';
  if FileExists(Path) then
  begin
    if AddFontResourceEx(PChar(Path), FR_PRIVATE, nil) > 0 then
      FFontPaths.Add(Path);
  end;
end;

procedure TMainForm.UnloadFonts;
var
  I: Integer;
begin
  if not Assigned(FFontPaths) then
    Exit;
  for I := 0 to FFontPaths.Count - 1 do
    RemoveFontResourceEx(PChar(FFontPaths[I]), FR_PRIVATE, nil);
  FreeAndNil(FFontPaths);
end;

procedure TMainForm.MeasureFonts;
var
  Bmp: TBitmap;
  W1, W2: Integer;
begin
  Bmp := TBitmap.Create;
  try
    Bmp.Canvas.Font.Assign(CharacterFont);
    CharacterSize := Bmp.Canvas.TextHeight('邊');
    W1 := Bmp.Canvas.TextWidth('邊');
    Bmp.Canvas.Font.Assign(PinyinFont);
    PinyinSize := Bmp.Canvas.TextHeight('chuán');
    W2 := Bmp.Canvas.TextWidth('chuán');
    ColumnWidth := Max(W1, W2) + 3;
  finally
    Bmp.Free;
  end;
end;

procedure TMainForm.SetupGrid;
var
  I: Integer;
begin
  Grid.RowCount := 2 * NRow;
  Grid.ColCount := NCol;
  Grid.FixedCols := 0;
  Grid.FixedRows := 0;
  Grid.DefaultDrawing := False;
  Grid.Options := [goVertLine, goHorzLine, goTabs];
  Grid.ScrollBars := ssVertical;
  Grid.Color := clWhite;
  Grid.GridLineWidth := 1;

  for I := 0 to Grid.RowCount - 1 do
  begin
    if Odd(I) then
      Grid.RowHeights[I] := CharacterSize
    else
      Grid.RowHeights[I] := PinyinSize;
  end;
  for I := 0 to Grid.ColCount - 1 do
    Grid.ColWidths[I] := ColumnWidth;
end;

procedure TMainForm.BuildUI;
var
  Work: TRect;
  HalfW, H: Integer;
  I, J, Pos: Integer;
  InitialChars: string;
  InitialPinyins: array of string;
begin
  Caption := 'HTML拼音校對';
  BorderStyle := bsSizeable;
  Position := poDesigned;
  OnClose := FormClose;
  KeyPreview := True;

  // 图标
  if FileExists(ExtractFilePath(ParamStr(0)) + 'res' + PathDelim + 'app-icon.ico') then
    Icon.LoadFromFile(ExtractFilePath(ParamStr(0)) + 'res' + PathDelim + 'app-icon.ico');

  // 窗口占屏幕右半边（等价于 getMaximumWindowBounds + setBounds）
  Work := Screen.WorkAreaRect;
  HalfW := Work.Width div 2;
  H := Work.Height;
  SetBounds(Work.Left + HalfW, Work.Top, HalfW, H);
  Constraints.MinWidth := Width;
  Constraints.MaxWidth := Width;
  Constraints.MinHeight := Height;
  Constraints.MaxHeight := Height;
  LoadFonts;

  CharacterFont := TFont.Create;
  CharacterFont.Name := CharacterFontName;
  CharacterFont.Height := 65; // 与 Java character_size=65 对应
  CharacterFont.Color := clBlack;
  PinyinFont := TFont.Create;
  PinyinFont.Name := PinyinFontName;
  PinyinFont.Height := 25;    // 与 Java pinyin_size=25 对应
  PinyinFont.Color := clBlack;

  MeasureFonts;

  // 按可用空间计算行列数（对应 Main.main 中的计算）
  NRow := Max(1, (ClientHeight - 90) div Max(1, CharacterSize + PinyinSize));
  NCol := Max(1, ClientWidth div Max(1, ColumnWidth));

  SetLength(Characters, NRow, NCol);
  SetLength(Pinyins, NRow, NCol);
  SetLength(CellEditable, NRow, NCol);
  SetLength(Contents, 2 * NRow, NCol);
  for I := 0 to NRow - 1 do
    for J := 0 to NCol - 1 do
      CellEditable[I][J] := True;
  // 初始内容："南無阿彌陀佛"
  InitialChars := '南無阿彌陀佛';
  for I := 0 to NRow - 1 do
    for J := 0 to NCol - 1 do
    begin
      case (I * NCol + J) mod 6 of
        0: Pinyins[I][J] := 'ná';
        1: Pinyins[I][J] := 'mó';
        2: Pinyins[I][J] := 'ē';
        3: Pinyins[I][J] := 'mí';
        4: Pinyins[I][J] := 'tuó';
      else
        Pinyins[I][J] := 'fó';
      end;
      Characters[I][J] := InitialChars[((I * NCol + J) mod 6) + 1];
    end;
  // 表格
  Grid := TStringGrid.Create(Self);
  Grid.Parent := Self;
  Grid.Align := alClient;
  Grid.OnDrawCell := GridDrawCell;
  Grid.OnSelectCell := GridSelectCell;
  Grid.OnDblClick := GridDblClick;
  Grid.OnKeyDown := GridKeyDown;
  SetupGrid;

  // 单元格编辑器（覆盖在网格之上）
  Editor := TEdit.Create(Self);
  Editor.Parent := Grid;
  Editor.Visible := False;
  Editor.BorderStyle := bsNone;
  Editor.OnKeyDown := EditorKeyDown;
  Editor.OnExit := EditorExit;

  Alerts := TStringList.Create;
  Alerts.Sorted := True;
  Alerts.Duplicates := dupIgnore;

  // 底部控制区（三行）
  PanelBottom := TPanel.Create(Self);
  PanelBottom.Parent := Self;
  PanelBottom.Align := alBottom;
  PanelBottom.Height := 84;
  PanelBottom.BevelOuter := bvNone;
  PanelBottom.Padding.SetBounds(4, 3, 4, 3);

  // 第一行：文件路径
  with TLabel.Create(Self) do
  begin
    Parent := PanelBottom; Caption := '文件路徑：';
    SetBounds(4, 4, 62, 23); AutoSize := False;
  end;
  PathEdit := TEdit.Create(Self);
  PathEdit.Parent := PanelBottom;
  PathEdit.SetBounds(68, 3, Max(120, PanelBottom.Width - 68 - 130), 23);
  PathEdit.Anchors := [akLeft, akTop, akRight];
  BtnBrowse := TButton.Create(Self);
  BtnBrowse.Parent := PanelBottom;
  BtnBrowse.Caption := '瀏覽';
  BtnBrowse.SetBounds(PanelBottom.Width - 124, 3, 56, 23);
  BtnBrowse.Anchors := [akTop, akRight];
  BtnBrowse.OnClick := BtnBrowseClick;
  BtnOpen := TButton.Create(Self);
  BtnOpen.Parent := PanelBottom;
  BtnOpen.Caption := '打開';
  BtnOpen.SetBounds(PanelBottom.Width - 64, 3, 56, 23);
  BtnOpen.Anchors := [akTop, akRight];
  BtnOpen.OnClick := BtnOpenClick;

  // 第二行：突出字符集
  with TLabel.Create(Self) do
  begin
    Parent := PanelBottom; Caption := '突出字符集：';
    SetBounds(4, 31, 82, 23); AutoSize := False;
  end;
  AlertEdit := TEdit.Create(Self);
  AlertEdit.Parent := PanelBottom;
  AlertEdit.SetBounds(88, 30, Max(80, PanelBottom.Width - 88 - 130), 23);
  AlertEdit.Anchors := [akLeft, akTop, akRight];
  BtnAlert := TButton.Create(Self);
  BtnAlert.Parent := PanelBottom;
  BtnAlert.Caption := '突出';
  BtnAlert.SetBounds(PanelBottom.Width - 124, 30, 56, 23);
  BtnAlert.Anchors := [akTop, akRight];
  BtnAlert.OnClick := BtnAlertClick;
  BtnCancelAlert := TButton.Create(Self);
  BtnCancelAlert.Parent := PanelBottom;
  BtnCancelAlert.Caption := '恢復';
  BtnCancelAlert.SetBounds(PanelBottom.Width - 64, 30, 56, 23);
  BtnCancelAlert.Anchors := [akTop, akRight];
  BtnCancelAlert.OnClick := BtnCancelAlertClick;

  // 第三行：翻页 / 保存 / 播放
  BtnPrev := TButton.Create(Self);
  BtnPrev.Parent := PanelBottom;
  BtnPrev.Caption := '←（Alt+←）';
  BtnPrev.SetBounds(4, 57, 92, 23);
  BtnPrev.OnClick := ActPrevExecute;
  with TLabel.Create(Self) do
  begin Parent := PanelBottom; Caption := '第'; SetBounds(100, 60, 16, 20); end;
  LblCurrentPage := TLabel.Create(Self);
  LblCurrentPage.Parent := PanelBottom;
  LblCurrentPage.SetBounds(118, 60, 30, 20);
  LblCurrentPage.Caption := '1';
  with TLabel.Create(Self) do
  begin Parent := PanelBottom; Caption := '頁'; SetBounds(150, 60, 16, 20); end;

  BtnSave := TButton.Create(Self);
  BtnSave.Parent := PanelBottom;
  BtnSave.Caption := '保存（Ctrl+S）';
  BtnSave.SetBounds(172, 57, 106, 23);
  BtnSave.OnClick := ActSaveExecute;

  BtnPlay := TButton.Create(Self);
  BtnPlay.Parent := PanelBottom;
  BtnPlay.Caption := '播放（Ctrl+P）';
  BtnPlay.SetBounds(284, 57, 106, 23);
  BtnPlay.OnClick := ActPlayExecute;

  with TLabel.Create(Self) do
  begin Parent := PanelBottom; Caption := '共'; SetBounds(396, 60, 16, 20); end;
  LblTotalPages := TLabel.Create(Self);
  LblTotalPages.Parent := PanelBottom;
  LblTotalPages.SetBounds(414, 60, 30, 20);
  LblTotalPages.Caption := '1';
  with TLabel.Create(Self) do
  begin Parent := PanelBottom; Caption := '頁'; SetBounds(446, 60, 16, 20); end;

  BtnNext := TButton.Create(Self);
  BtnNext.Parent := PanelBottom;
  BtnNext.Caption := '→（Alt+→）';
  BtnNext.SetBounds(470, 57, 92, 23);
  BtnNext.OnClick := ActNextExecute;

  // 快捷键（等价于 registerKeyboardAction）
  ActionList := TActionList.Create(Self);
  ActPrev := TAction.Create(ActionList);
  ActPrev.Caption := '上一頁';
  ActPrev.ShortCut := ShortCut(VK_LEFT, [ssAlt]);
  ActPrev.OnExecute := ActPrevExecute;
  ActPrev.ActionList := ActionList;
  ActNext := TAction.Create(ActionList);
  ActNext.Caption := '下一頁';
  ActNext.ShortCut := ShortCut(VK_RIGHT, [ssAlt]);
  ActNext.OnExecute := ActNextExecute;
  ActNext.ActionList := ActionList;
  ActSave := TAction.Create(ActionList);
  ActSave.Caption := '保存';
  ActSave.ShortCut := ShortCut(Ord('S'), [ssCtrl]);
  ActSave.OnExecute := ActSaveExecute;
  ActSave.ActionList := ActionList;
  ActPlay := TAction.Create(ActionList);
  ActPlay.Caption := '播放';
  ActPlay.ShortCut := ShortCut(Ord('P'), [ssCtrl]);
  ActPlay.OnExecute := ActPlayExecute;
  ActPlay.ActionList := ActionList;

  OpenDialog := TOpenDialog.Create(Self);
  OpenDialog.InitialDir := GetCurrentDir;

  // 播放回调
  uState.PlayTick := PlayTickCallback;
  uState.PlayNextPage := PlayNextPageCallback;
  RenewAndRepaint;
end;

procedure TMainForm.RenewAndRepaint;
begin
  uState.RenewContents;
  Grid.Repaint;
end;

procedure TMainForm.GridDrawCell(Sender: TObject; ACol, ARow: Integer;
  Rect: TRect; State: TGridDrawState);
var
  Text, CharText: string;
  F: TFont;
  C: TColor;
  R: TRect;
  Highlight: Boolean;
begin
  if (ARow < 0) or (ARow >= Length(Contents)) or (ACol < 0) or (ACol >= NCol) then
    Exit;

  Text := Contents[ARow, ACol];
  if Odd(ARow) then
    F := CharacterFont
  else
    F := PinyinFont;

  // 与 Java 一致：根据该列汉字是否在突出字符集中决定颜色
  CharText := Contents[2 * (ARow div 2) + 1, ACol];
  if IsAlert(CharText) then
    C := AlertColor
  else
    C := clBlack;

  // 播放时：当前朗读字所在的整列（拼音行+汉字行）用高亮背景显示
  Highlight := uState.PlayHighlight and
               (ACol = uState.PlayCurCol) and
               ((ARow = 2 * uState.PlayCurRow) or
                (ARow = 2 * uState.PlayCurRow + 1));
  if Highlight then
    Grid.Canvas.Brush.Color := uState.PlayHighlightColor
  else
    Grid.Canvas.Brush.Color := clWhite;
  Grid.Canvas.FillRect(Rect);
  Grid.Canvas.Font.Assign(F);
  Grid.Canvas.Font.Color := C;

  R := Rect;
  InflateRect(R, -1, -1);
  DrawText(Grid.Canvas.Handle, PChar(Text), Length(Text), R,
    DT_CENTER or DT_VCENTER or DT_SINGLELINE);
end;

procedure TMainForm.GridSelectCell(Sender: TObject; ACol, ARow: Integer;
  var CanSelect: Boolean);
begin
  CanSelect := True;
end;

procedure TMainForm.BeginEdit(ACol, ARow: Integer);
var
  R: TRect;
begin
  if (ARow div 2 >= NRow) or (ACol >= NCol) then
    Exit;
  if not CellEditable[ARow div 2, ACol] then
    Exit;

  CommitEditor;
  FEditRow := ARow;
  FEditCol := ACol;
  FEditing := True;

  R := Grid.CellRect(ACol, ARow);
  Editor.SetBounds(R.Left, R.Top, R.Right - R.Left, R.Bottom - R.Top);
  if Odd(ARow) then
  begin
    Editor.Font.Assign(CharacterFont);
    Editor.MaxLength := 1; // 汉字单元格只允许一个字符
    if Length(Contents[ARow, ACol]) > 1 then
      Editor.Text := Copy(Contents[ARow, ACol], Length(Contents[ARow, ACol]), 1)
    else
      Editor.Text := Contents[ARow, ACol];
  end
  else
  begin
    Editor.Font.Assign(PinyinFont);
    Editor.MaxLength := 0;
    Editor.Text := Contents[ARow, ACol];
  end;

  Editor.Visible := True;
  Editor.SetFocus;
  Editor.SelectAll;
end;

procedure TMainForm.CommitEditor;
begin
  if not FEditing then
    Exit;
  FEditing := False;
  if (FEditRow >= 0) and (FEditRow < Length(Contents)) and
     (FEditCol >= 0) and (FEditCol < NCol) then
    Contents[FEditRow, FEditCol] := Editor.Text;
  Editor.Visible := False;
  uState.PullContents;
  Grid.Repaint;
end;

procedure TMainForm.EditorExit(Sender: TObject);
begin
  CommitEditor;
end;

procedure TMainForm.EditorKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key = VK_RETURN then
  begin
    CommitEditor;
    Grid.SetFocus;
    Key := 0;
  end
  else if Key = VK_ESCAPE then
  begin
    FEditing := False;
    Editor.Visible := False;
    Grid.SetFocus;
    Key := 0;
  end;
end;

procedure TMainForm.GridDblClick(Sender: TObject);
begin
  BeginEdit(Grid.Col, Grid.Row);
end;

procedure TMainForm.GridKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  // 与 JTable 一致：直接键入字符即可编辑当前单元格
  if (Key = VK_RETURN) or ((Key >= Ord('A')) and (Key <= Ord('Z'))) or
     ((Key >= Ord('a')) and (Key <= Ord('z'))) then
    BeginEdit(Grid.Col, Grid.Row);
end;

procedure TMainForm.BtnBrowseClick(Sender: TObject);
begin
  OpenDialog.InitialDir := ExtractFilePath(PathEdit.Text);
  if OpenDialog.Execute then
    PathEdit.Text := OpenDialog.FileName;
end;

procedure TMainForm.BtnOpenClick(Sender: TObject);
begin
  CommitEditor;
  if not FileExists(PathEdit.Text) then
  begin
    MessageDlg('文件不存在。', mtError, [mbOK], 0);
    Exit;
  end;
  uFileProcessor.Filename := PathEdit.Text;
  if uFileProcessor.Load then
    RenewAndRepaint
  else
    MessageDlg('文件無法讀取。', mtError, [mbOK], 0);
end;

procedure TMainForm.BtnAlertClick(Sender: TObject);
var
  I: Integer;
  S: string;
begin
  Alerts.Clear;
  S := AlertEdit.Text;
  for I := 1 to Length(S) do
    Alerts.Add(S[I]);
  Grid.Repaint;
end;

procedure TMainForm.BtnCancelAlertClick(Sender: TObject);
begin
  Alerts.Clear;
  Grid.Repaint;
end;

procedure TMainForm.ActPrevExecute(Sender: TObject);
begin
  CommitEditor;
  if (uFileProcessor.Filename = '') or not FileExists(uFileProcessor.Filename) then
  begin
    MessageDlg('未打開文件。', mtError, [mbOK], 0);
    Exit;
  end;
  uState.PullContents;
  uFileProcessor.PreviousPage;
  RenewAndRepaint;
end;

procedure TMainForm.ActNextExecute(Sender: TObject);
begin
  CommitEditor;
  if (uFileProcessor.Filename = '') or not FileExists(uFileProcessor.Filename) then
  begin
    MessageDlg('未打開文件。', mtError, [mbOK], 0);
    Exit;
  end;
  uState.PullContents;
  uFileProcessor.NextPage;
  RenewAndRepaint;
end;

procedure TMainForm.ActSaveExecute(Sender: TObject);
begin
  CommitEditor;
  if (uFileProcessor.Filename = '') or not FileExists(uFileProcessor.Filename) then
  begin
    MessageDlg('文件不存在。', mtError, [mbOK], 0);
    Exit;
  end;
  uState.PullContents;
  if uFileProcessor.Save then
    BtnSave.Caption := '保存(Ctrl+S)' + FormatDateTime('tt', Now)
  else
    MessageDlg('文件無法寫入。', mtError, [mbOK], 0);
end;

procedure TMainForm.ActPlayExecute(Sender: TObject);
begin
  if not uAudio.IsPlaying then
  begin
    if Length(uFileProcessor.Filename) = 0 then
      Exit;
    CommitEditor;
    uState.PullContents;
    uState.PlayStartRow := Grid.Row;
    uState.PlayStartCol := Grid.Col;
    uState.PlayHighlight := True;  // 开启当前朗读字高亮
    Grid.Repaint;
    uAudio.Play;
    BtnPlay.Caption := '暫停（Ctrl+P）';
  end
  else
  begin
    uAudio.StopPlay;
    uState.PlayHighlight := False;  // 停止朗读后取消高亮
    Grid.Repaint;
    BtnPlay.Caption := '播放（Ctrl+P）';
  end;
end;

procedure TMainForm.PlayTickCallback;
begin
  Grid.Row := 2 * uState.PlayCurRow;
  Grid.Col := uState.PlayCurCol;
  Grid.Repaint;
end;

procedure TMainForm.PlayNextPageCallback;
begin
  uState.PullContents;
  uFileProcessor.NextPage;
  RenewAndRepaint;
end;

procedure TMainForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  uAudio.StopPlay;
  uState.PlayHighlight := False;
  uRecord.WriteRecords;
end;

end.
