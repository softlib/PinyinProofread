unit uAudio;

interface

/// <summary>
/// 对应 Java 的 Audio 类。使用 Windows MCI 播放内置拼音音节库，
/// 在独立线程中顺序朗读，支持暂停（Ctrl+P）与自动翻页。
/// </summary>
procedure Play;
procedure StopPlay;
function IsPlaying: Boolean;

implementation

uses
  System.Classes, System.SysUtils, System.Math, System.IOUtils,
  Winapi.Windows, Winapi.MMSystem,
  uState, uFileProcessor;

var
  IsPlay: Boolean = False;
  PlayThread: TThread = nil;

function ResourcePath(const AFileName: string): string;
var
  Base: string;
begin
  Base := ExtractFilePath(ParamStr(0));
  Result := Base + 'res' + PathDelim + AFileName;
  if not FileExists(Result) then
    Result := Base + AFileName;
end;

/// <summary>对应 Audio.audio_play：播放单个音节，阻塞至播放结束/暂停。</summary>
procedure AudioPlay(const APinyin: string);
var
  FilePath, Buf: string;
  Mode: array[0..31] of Char;
begin
  FilePath := ResourcePath('yinjies' + PathDelim + APinyin + '.mp3');
  if not FileExists(FilePath) then
  begin
    // Java 中 getResource 返回 null 后 sleep(1000)
    Sleep(1000);
    Exit;
  end;

  FillChar(Mode, SizeOf(Mode), 0);
  // 先关闭可能残留的别名
  mciSendString('close pinyinAlias', nil, 0, 0);
  Buf := 'open "' + FilePath + '" type mpegvideo alias pinyinAlias';
  if mciSendString(PChar(Buf), nil, 0, 0) <> 0 then
  begin
    Sleep(1000);
    Exit;
  end;

  mciSendString('play pinyinAlias', nil, 0, 0);
  try
    // 对应 Java 的 25ms 轮询：等待播放停止/暂停或用户按下暂停
    while IsPlay do
    begin
      FillChar(Mode, SizeOf(Mode), 0);
      mciSendString('status pinyinAlias mode', @Mode[0], SizeOf(Mode), 0);
      if (CompareText(string(Mode), 'stopped') = 0) or
         (CompareText(string(Mode), 'paused') = 0) then
        Break;
      Sleep(25);
    end;
  finally
    mciSendString('stop pinyinAlias', nil, 0, 0);
    mciSendString('close pinyinAlias', nil, 0, 0);
  end;
end;

type
  TPlayerThread = class(TThread)
  private
    FStartRow, FStartCol: Integer;
    procedure SyncReadStart;
    procedure SyncTick;
    procedure SyncNextPage;
  protected
    procedure Execute; override;
  end;

procedure TPlayerThread.SyncReadStart;
begin
  FStartRow := uState.PlayStartRow;
  FStartCol := uState.PlayStartCol;
end;

procedure TPlayerThread.SyncTick;
begin
  if Assigned(uState.PlayTick) then
    uState.PlayTick();
end;

procedure TPlayerThread.SyncNextPage;
begin
  if Assigned(uState.PlayNextPage) then
    uState.PlayNextPage();
end;

procedure TPlayerThread.Execute;
var
  RowIdx, ColIdx: Integer;
  Blanked: Boolean;
  Block: TBlock;
begin
  Synchronize(SyncReadStart);

  // 对应 Java: Math.max(0, selectedRow)/2 , Math.max(0, selectedColumn)
  RowIdx := Max(0, FStartRow) div 2;
  ColIdx := Max(0, FStartCol);
  Blanked := False;

  while IsPlay and (not Terminated) do
  begin
    // 记录当前朗读位置，供主窗体高亮
    uState.PlayCurRow := RowIdx;
    uState.PlayCurCol := ColIdx;

    // 高亮当前朗读单元格
    Synchronize(SyncTick);

    Block := uFileProcessor.GetCurrentPageBlock(RowIdx, ColIdx);
    if Assigned(Block) and (Block.Pinyin <> '') then
    begin
      Blanked := False;
      AudioPlay(Block.Pinyin);
    end
    else if not Blanked then
    begin
      Blanked := True;
      Sleep(1000);
    end;

    RowIdx := uFileProcessor.GetNextRowIndex(RowIdx, ColIdx, NRow, NCol);
    ColIdx := uFileProcessor.GetNextColumnIndex(RowIdx, ColIdx, NRow, NCol);

    if (RowIdx = 0) and (ColIdx = 0) then
      Synchronize(SyncNextPage);
  end;
end;

procedure Play;
begin
  if IsPlay then
    Exit;
  if Length(uFileProcessor.Filename) = 0 then
    Exit;
  IsPlay := True;
  PlayThread := TPlayerThread.Create(True);
  TPlayerThread(PlayThread).FreeOnTerminate := True;
  PlayThread.Start;
end;

procedure StopPlay;
begin
  IsPlay := False;
  // 立即停止当前 MCI 播放，让轮询尽快退出
  mciSendString('stop pinyinAlias', nil, 0, 0);
end;

function IsPlaying: Boolean;
begin
  Result := IsPlay;
end;

end.
