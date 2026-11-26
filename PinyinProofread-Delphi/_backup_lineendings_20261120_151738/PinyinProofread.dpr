program PinyinProofread;

uses
  Vcl.Forms,
  uMain in 'src\uMain.pas',
  uState in 'src\uState.pas',
  uRecord in 'src\uRecord.pas',
  uFileProcessor in 'src\uFileProcessor.pas',
  uAudio in 'src\uAudio.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
