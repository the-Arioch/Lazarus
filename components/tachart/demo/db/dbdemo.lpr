program dbdemo;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, Main, MemDSLaz, TAChartLazarusPkg
  { you can add units after this };

{$R *.res}

begin
  Application.Title:='Chart db-aware demo';
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.

