{
 *****************************************************************************
  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************

 Authors: Maciej Izak
          Michael W. Vogel

 This is the access to one SourceEditor window. There can be more then just one
 (that list is SourceEditorWindows).
 Each SourceEditor window can hold a lot of units, forms etc. available per
 SourceEditorWindowInterface in PageControlList.

}

unit DockedSourceEditorWindow;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$modeswitch typehelpers}

{ $define DEBUGDOCKEDFORMEDITOR}

interface

uses
  // RTL
  Classes, SysUtils, fgl,
  // LCL
  Forms, Controls, LCLProc,
  // IDEIntf
  SrcEditorIntf, LazIDEIntf, FormEditingIntf, ExtendedNotebook,
  // DockedFormEditor
  DockedSourceEditorPageControls, DockedDesignForm, DockedModulePageControl,
  DockedOptionsIDE, DockedTools;

type

  { TSourceEditorWindow }

  TSourceEditorWindow = class
  private
    FActiveDesignForm: TDesignForm;
    FLastActiveSourceEditor: TSourceEditorInterface;
    FLastTopParent: TControl;
    FNotebookPageChanged: TNotifyEvent;
    FPageControlList: TSourceEditorPageControls;
    FSourceEditorNotebook: TExtendedNotebook;
    FSourceEditorWindowInterface: TSourceEditorWindowInterface;
    function GetActiveEditor: TSourceEditorInterface;
    procedure HookIntoOnPageChanged;
    procedure SetActiveDesignForm(const AValue: TDesignForm);
    procedure SourceEditorPageChanged(Sender: TObject);
    procedure UpdateEditorPageCaption(Sender: TObject);
  public
    constructor Create(ASourceEditorWindowInterface: TSourceEditorWindowInterface);
    destructor Destroy; override;
    procedure AddPageCtrl(ASourceEditor: TSourceEditorInterface; APageControl: TModulePageControl);
    procedure AdjustPageControl;
    function  FindModulePageControl(ASourceEditor: TSourceEditorInterface): TModulePageControl;
    procedure RemoveActiveDesignForm;
    procedure RemovePageCtrl(ASourceEditor: TSourceEditorInterface);
  public
    property ActiveDesignForm: TDesignForm read FActiveDesignForm write SetActiveDesignForm;
    property ActiveEditor: TSourceEditorInterface read GetActiveEditor;
    property LastActiveSourceEditor: TSourceEditorInterface read FLastActiveSourceEditor write FLastActiveSourceEditor;
    property LastTopParent: TControl read FLastTopParent write FLastTopParent;
    property PageControlList: TSourceEditorPageControls read FPageControlList;
    property SourceEditorWindowInterface: TSourceEditorWindowInterface read FSourceEditorWindowInterface;
  end;

  { TSourceEditorWindows }

  TSourceEditorWindows = class(specialize TFPGList<TSourceEditorWindow>)
  private
    FLastActiveSourceEditorWindow: TSourceEditorWindowInterface;
    function GetLastActiveModulePageControl: TModulePageControl;
    function GetLastActiveSourceEditor: TSourceEditorInterface;
    function GetWindowInterface(ASrcEditor: TSourceEditorWindow): TSourceEditorWindowInterface;
    function GetSourceEditorWindow(AWindowInterface: TSourceEditorWindowInterface): TSourceEditorWindow;
    procedure SetLastActiveSourceEditor(AValue: TSourceEditorInterface);
  public
    constructor CreateNew;
    destructor Destroy; override;
    function  Contains(AWindowInterface: TSourceEditorWindowInterface): Boolean;
    function  Contains(ASrcEditor: TSourceEditorWindow): Boolean;
    procedure DeleteItem(Index: Integer);
    function  FindDesignForm(AModulePageCtrl: TModulePageControl): TDesignForm;
    function  FindModulePageControl(ASrcEditor: TSourceEditorInterface): TModulePageControl;
    function  IndexOf(AWindowInterface: TSourceEditorWindowInterface): Integer; overload;
    function  LastSourceEditorNotFound: Boolean;
    procedure RefreshActivePageControls;
    procedure RefreshAllPageControls;
    procedure Remove(AWindowInterface: TSourceEditorWindowInterface); overload;
    procedure ShowCodeTabSkipCurrent(CurrentPageCtrl: TModulePageControl; ADesignForm: TDesignForm);
  public
    property LastActiveSourceEditorWindow: TSourceEditorWindowInterface read FLastActiveSourceEditorWindow write FLastActiveSourceEditorWindow;
    property LastActiveSourceEditor: TSourceEditorInterface read GetLastActiveSourceEditor write SetLastActiveSourceEditor;
    property LastActiveModulePageControl: TModulePageControl read GetLastActiveModulePageControl;
    property WindowInterface[ASrcEditor: TSourceEditorWindow]: TSourceEditorWindowInterface read GetWindowInterface;
    property SourceEditorWindow[AWindowInterface: TSourceEditorWindowInterface]: TSourceEditorWindow read GetSourceEditorWindow;
  end;

var
  SourceEditorWindows: TSourceEditorWindows;

implementation

{ TSourceEditorWindow }

procedure TSourceEditorWindow.HookIntoOnPageChanged;
var
  i: Integer;
begin
  for i := 0 to FSourceEditorWindowInterface.ControlCount - 1 do
    if FSourceEditorWindowInterface.Controls[i] is TExtendedNotebook then
    begin
      FSourceEditorNotebook := TExtendedNotebook(FSourceEditorWindowInterface.Controls[i]);
      Break;
    end;
  if not Assigned(FSourceEditorNotebook) then Exit;
  FNotebookPageChanged := FSourceEditorNotebook.OnChange;
  FSourceEditorNotebook.OnChange := @SourceEditorPageChanged;
end;

function TSourceEditorWindow.GetActiveEditor: TSourceEditorInterface;
begin
  Result := FSourceEditorWindowInterface.ActiveEditor;
end;

procedure TSourceEditorWindow.SetActiveDesignForm(const AValue: TDesignForm);
var
  LPageCtrl: TModulePageControl;
begin
  if FActiveDesignForm = AValue then Exit;
  if FActiveDesignForm <> nil then
    // don't hide now if soon form will be hidden (for example on the IDE start)
    if not FActiveDesignForm.Hiding then
      FActiveDesignForm.HideWindow;
  FActiveDesignForm := AValue;

  LPageCtrl := FindModulePageControl(ActiveEditor);
  // important when we want back to tab where was oppened form
  if (AValue <> nil) then
    LazarusIDE.DoShowDesignerFormOfSrc(ActiveEditor);

  if LPageCtrl = nil then Exit;
  LPageCtrl.DesignForm := AValue;
end;

procedure TSourceEditorWindow.SourceEditorPageChanged(Sender: TObject);
var
  LPageCtrl: TModulePageControl;
begin
  {$IFDEF DEBUGDOCKEDFORMEDITOR} DebugLn('TSourceEditorWindow.SourceEditorPageChanged SourceEditorWindow[' + FSourceEditorWindowInterface.Caption + ']'); {$ENDIF}
  FNotebookPageChanged(Sender);
  LPageCtrl := FindModulePageControl(ActiveEditor);
  if not Assigned(LPageCtrl) then Exit;
  if LPageCtrl.DesignerPageActive then
  begin
    LPageCtrl.AdjustPage;
    {$IF DEFINED(LCLGtk2)}
      LPageCtrl.DesignerSetFocusAsync;
    {$ELSE}
      LPageCtrl.DesignerSetFocus;
    {$ENDIF}
  end;
end;

procedure TSourceEditorWindow.UpdateEditorPageCaption(Sender: TObject);
var
  LSourceEditor: TSourceEditorInterface;
  LSourceEditorWindow: TSourceEditorWindowInterface;
begin
  // if a unit is cloned to undocked empty source editor window, the ModulePageControl
  // is not created, the only workaround I found is, to activate the new created
  // source editor in this window
  if not (Sender is TSourceEditorInterface) then Exit;
  if SourceEditorManagerIntf.ActiveSourceWindow = nil then Exit;
  LSourceEditor := TSourceEditorInterface(Sender);
  {$IFDEF DEBUGDOCKEDFORMEDITOR} DebugLn('TSourceEditorWindow.UpdateEditorPageCaption [' + SourceEditorWindowCaption(LSourceEditor) + ']'); {$ENDIF}
  LSourceEditorWindow := SourceEditorWindow(LSourceEditor);
  if not Assigned(LSourceEditorWindow)
  or (SourceEditorManagerIntf.ActiveSourceWindow = LSourceEditorWindow)
  or (SourceEditorWindows.LastActiveSourceEditorWindow = LSourceEditorWindow)
  then
    Exit;
  LSourceEditorWindow.ActiveEditor := LSourceEditor;
end;

constructor TSourceEditorWindow.Create(ASourceEditorWindowInterface: TSourceEditorWindowInterface);
begin
  FLastActiveSourceEditor := nil;
  FSourceEditorWindowInterface := ASourceEditorWindowInterface;
  FPageControlList := TSourceEditorPageControls.Create;
  FSourceEditorNotebook := nil;
  HookIntoOnPageChanged;
  FSourceEditorWindowInterface.AddUpdateEditorPageCaptionHandler(@UpdateEditorPageCaption);
end;

destructor TSourceEditorWindow.Destroy;
begin
  if Assigned(FSourceEditorNotebook) then
    FSourceEditorNotebook.OnChange := FNotebookPageChanged;
  FPageControlList.Free;
  inherited Destroy;
end;

procedure TSourceEditorWindow.AddPageCtrl(ASourceEditor: TSourceEditorInterface; APageControl: TModulePageControl);
begin
  FPageControlList.Add(ASourceEditor, APageControl);
end;

procedure TSourceEditorWindow.AdjustPageControl;
var
  LPageCtrl: TModulePageControl;
begin
  LPageCtrl := FindModulePageControl(ActiveEditor);
  if LPageCtrl <> nil then
    LPageCtrl.AdjustPage;
end;

function TSourceEditorWindow.FindModulePageControl(ASourceEditor: TSourceEditorInterface): TModulePageControl;
var
  LParent: TWinControl;
begin
  if ASourceEditor = nil then
    Exit(nil);
  LParent := ASourceEditor.EditorControl.Parent;
  while LParent <> nil do
  begin
    if LParent is TModulePageControl then
      Exit(TModulePageControl(LParent));
    LParent := LParent.Parent;
  end;
  Result := nil;
end;

procedure TSourceEditorWindow.RemoveActiveDesignForm;
begin
  FActiveDesignForm := nil;
end;

procedure TSourceEditorWindow.RemovePageCtrl(ASourceEditor: TSourceEditorInterface);
begin
  FPageControlList.Remove(ASourceEditor);
  if LastActiveSourceEditor = ASourceEditor then
    LastActiveSourceEditor := nil;
end;

{ TSourceEditorWindows }

function TSourceEditorWindows.GetWindowInterface(ASrcEditor: TSourceEditorWindow): TSourceEditorWindowInterface;
var
  LIndex: Integer;
begin
  LIndex := IndexOf(ASrcEditor);
  if LIndex >= 0 then
    Result := Items[LIndex].SourceEditorWindowInterface
  else
    Result := nil;
end;

function TSourceEditorWindows.GetLastActiveModulePageControl: TModulePageControl;
begin
  Result := FindModulePageControl(LastActiveSourceEditor);
end;

function TSourceEditorWindows.GetLastActiveSourceEditor: TSourceEditorInterface;
var
  LSourceEditorWindow: TSourceEditorWindow;
begin
  Result := nil;
  if not Assigned(LastActiveSourceEditorWindow) then Exit;
  LSourceEditorWindow := SourceEditorWindow[LastActiveSourceEditorWindow];
  if not Assigned(LSourceEditorWindow) then Exit;
  Result := LSourceEditorWindow.LastActiveSourceEditor;
end;

function TSourceEditorWindows.GetSourceEditorWindow(AWindowInterface: TSourceEditorWindowInterface): TSourceEditorWindow;
var
  LIndex: Integer;
begin
  LIndex := IndexOf(AWindowInterface);
  if LIndex >= 0 then
    Result := Items[LIndex]
  else
    Result := nil;
end;

procedure TSourceEditorWindows.SetLastActiveSourceEditor(AValue: TSourceEditorInterface);
var
  LSourceEditorWindow: TSourceEditorWindow;
begin
  if not Assigned(LastActiveSourceEditorWindow) then Exit;
  LSourceEditorWindow := SourceEditorWindow[LastActiveSourceEditorWindow];
  if not Assigned(LSourceEditorWindow) then Exit;
  LSourceEditorWindow.LastActiveSourceEditor := AValue;
end;

constructor TSourceEditorWindows.CreateNew;
begin
  inherited Create;
  FLastActiveSourceEditorWindow := nil;
end;

destructor TSourceEditorWindows.Destroy;
begin
  while Count > 0 do
    DeleteItem(0);
  inherited Destroy;
end;

function TSourceEditorWindows.Contains(AWindowInterface: TSourceEditorWindowInterface): Boolean;
begin
  Result := IndexOf(AWindowInterface) >= 0;
end;

function TSourceEditorWindows.Contains(ASrcEditor: TSourceEditorWindow): Boolean;
begin
  Result := IndexOf(ASrcEditor) >= 0;
end;

procedure TSourceEditorWindows.DeleteItem(Index: Integer);
var
  LSourceEditorWindow: TSourceEditorWindow;
begin
  LSourceEditorWindow := Items[Index];
  LSourceEditorWindow.Free;
  Delete(Index);
end;

function TSourceEditorWindows.FindDesignForm(AModulePageCtrl: TModulePageControl): TDesignForm;
var
  LSourceEditorWindow: TSourceEditorWindow;
  LSourceEditorInterface: TSourceEditorInterface;
begin
  Result := nil;
  if AModulePageCtrl = nil then Exit;
  for LSourceEditorWindow in Self do
  begin
    if AModulePageCtrl.Owner = LSourceEditorWindow.SourceEditorWindowInterface then
    begin
      LSourceEditorInterface := LSourceEditorWindow.ActiveEditor;
      if LSourceEditorInterface = nil then Exit;
      Result := DesignForms.Find(LSourceEditorInterface.GetDesigner(True));
      Exit;
    end;
  end;
end;

function TSourceEditorWindows.FindModulePageControl(ASrcEditor: TSourceEditorInterface): TModulePageControl;
var
  LSourceEditorWindow: TSourceEditorWindow;
begin
  Result := nil;
  for LSourceEditorWindow in Self do
    if LSourceEditorWindow.PageControlList.Contains(ASrcEditor) then
      Exit(LSourceEditorWindow.PageControlList.PageControl[ASrcEditor]);
end;

function TSourceEditorWindows.IndexOf(AWindowInterface: TSourceEditorWindowInterface): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to Count - 1 do
    if Items[i].SourceEditorWindowInterface = AWindowInterface then
      Exit(i);
end;

function TSourceEditorWindows.LastSourceEditorNotFound: Boolean;
var
  i: Integer;
  LSourceEditorPageControl: TSourceEditorPageControl;
  LSourceEditorWindow: TSourceEditorWindow;
begin
  if (LastActiveSourceEditorWindow = nil) or (LastActiveSourceEditor = nil) then
    Exit(False);

  LSourceEditorWindow := SourceEditorWindow[LastActiveSourceEditorWindow];
  for LSourceEditorPageControl in LSourceEditorWindow.PageControlList do
  begin
    Result := True;
    for i := 0 to LastActiveSourceEditorWindow.Count - 1 do
      if LSourceEditorPageControl.SourceEditor = LastActiveSourceEditorWindow.Items[i] then
      begin
        Result := False;
        Break;
      end;
    if Result then
    begin
      // after moving code editor into other window, sometimes IDE switch to other tab
      // this line prevent this.
      LSourceEditorWindow.LastActiveSourceEditor := LSourceEditorPageControl.SourceEditor;
      Exit;
    end;
  end;
  Result := False;
end;

procedure TSourceEditorWindows.RefreshActivePageControls;
var
  LWindow: TSourceEditorWindow;
  LPageCtrl: TModulePageControl;
begin
  for LWindow in Self do
  begin
    LPageCtrl := LWindow.FindModulePageControl(LWindow.ActiveEditor);
    // for example LPageCtrl is nil when we clone module to new window
    if (LPageCtrl = nil) or (csDestroying in LWindow.SourceEditorWindowInterface.ComponentState) then
      Continue;
    if (LWindow.ActiveEditor = nil)
    or (LWindow.ActiveEditor.GetDesigner(True) <> nil)
    then
      LPageCtrl.RemoveDesignPages
    else
      if Assigned(LPageCtrl.DesignForm) then
      begin
        LPageCtrl.CreateTabSheetDesigner;
        if not (LPageCtrl.DesignForm.Form is TNonControlProxyDesignerForm) then
          LPageCtrl.CreateTabSheetAnchors;
      end;
  end;
end;

procedure TSourceEditorWindows.RefreshAllPageControls;
var
  LWindow: TSourceEditorWindow;
  LSourceEditorPageControl: TSourceEditorPageControl;
begin
  for LWindow in SourceEditorWindows do
    for LSourceEditorPageControl in LWindow.PageControlList do
    begin
      LSourceEditorPageControl.PageControl.TabPosition := DockedOptions.TabPosition;
      LSourceEditorPageControl.PageControl.RefreshResizer;
    end;
end;

procedure TSourceEditorWindows.Remove(AWindowInterface: TSourceEditorWindowInterface);
var
  LIndex: Integer;
begin
  LIndex := IndexOf(AWindowInterface);
  if LIndex < 0 then Exit;
  DeleteItem(LIndex);
  if LastActiveSourceEditorWindow = AWindowInterface then
    LastActiveSourceEditorWindow := nil;
end;

procedure TSourceEditorWindows.ShowCodeTabSkipCurrent(CurrentPageCtrl: TModulePageControl; ADesignForm: TDesignForm);
var
  LSourceEditorWindow: TSourceEditorWindow;
  LSourceEditorPageControl: TSourceEditorPageControl;
begin
  for LSourceEditorWindow in Self do
    for LSourceEditorPageControl in LSourceEditorWindow.PageControlList do
      if LSourceEditorPageControl.PageControl = CurrentPageCtrl then
      begin
        LSourceEditorPageControl.PageControl.DesignForm := ADesignForm;
        LSourceEditorPageControl.PageControl.InitPage;
      end else
        if LSourceEditorPageControl.PageControl.DesignForm = ADesignForm then
          LSourceEditorPageControl.PageControl.ShowCode;
end;

initialization
  SourceEditorWindows := TSourceEditorWindows.CreateNew;

finalization
  SourceEditorWindows.Free;

end.

