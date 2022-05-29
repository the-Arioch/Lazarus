unit iprotest_unit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  EditBtn, ComCtrls, SynEdit, SynHighlighterHTML, IpHtml;

type
  
  { TForm1 }

  TForm1 = class(TForm)
    btnRender: TButton;
    btnShowInBrowser: TButton;
    btnLoadFromFile: TButton;
    FileNameEdit1: TFileNameEdit;
    IpHtmlPanel1: TIpHtmlPanel;
    Label1: TLabel;
    Memo1: TMemo;
    Panel1: TPanel;
    Panel2: TPanel;
    Panel3: TPanel;
    Panel4: TPanel;
    Splitter1: TSplitter;
    Splitter2: TSplitter;
    Splitter3: TSplitter;
    SynEdit1: TSynEdit;
    SynHTMLSyn1: TSynHTMLSyn;
    TreeView1: TTreeView;
    procedure btnRenderClick(Sender: TObject);
    procedure btnShowInBrowserClick(Sender: TObject);
    procedure btnLoadFromFileClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure TreeView1Deletion(Sender: TObject; Node: TTreeNode);
    procedure TreeView1SelectionChanged(Sender: TObject);
  private
    procedure PopulateTests;

  public
    procedure AddTest(ANode: TTreeNode; ATitle, ADescription, AHtml: String);

  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

uses
  LCLIntf, ipro_tests;

type
  TTestCase = class
    Description: String;
    HTML: String;
  end;
  

{ TForm1 }

procedure TForm1.AddTest(ANode: TTreeNode; ATitle, ADescription, AHtml: String);
var
  testcase: TTestCase;
begin
  testcase := TTestCase.Create;
  testcase.Description := ADescription;
  testcase.HTML := AHtml;
  TreeView1.Items.AddChildObject(ANode, ATitle, testcase);
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  SynEdit1.Font.Quality := fqCleartype;
  PopulateTests;
end;

procedure TForm1.TreeView1Deletion(Sender: TObject; Node: TTreeNode);
begin
  if (TObject(Node.Data) is TTestCase) then
    TTestCase(Node.Data).Free;
end;

procedure TForm1.btnRenderClick(Sender: TObject);
begin
  IpHtmlPanel1.SetHtmlFromStr(SynEdit1.Lines.Text);
end;

procedure TForm1.btnShowInBrowserClick(Sender: TObject);
const
  TEST_FILE = 'test.html';
begin
  SynEdit1.Lines.SaveToFile(TEST_FILE);
  OpenURL(TEST_FILE);
end;

procedure TForm1.btnLoadFromFileClick(Sender: TObject);
begin
  with TOpenDialog.Create(nil) do 
    try
      filter := 'HTML files (*.html; *.htm)|*.html;*.htm';
      if FileName <> '' then
        InitialDir := ExtractFileDir(FileName);
      Options := Options + [ofFileMustExist];
      if Execute then
      begin
        Memo1.Lines.Clear;
        SynEdit1.Lines.LoadFromFile(FileName);
        IpHtmlPanel1.SetHtmlFromStr(SynEdit1.Lines.Text);
      end;
    finally
      Free;
    end;
end;

procedure TForm1.TreeView1SelectionChanged(Sender: TObject);
var
  testcase: TTestCase;
begin
  if TreeView1.Selected = nil then
    exit;
  testCase := TTestCase(TreeView1.Selected.Data);
  if testCase <> nil then 
  begin
    Memo1.Lines.Text := testCase.Description;
    Synedit1.Lines.Text := testCase.html;
    IpHtmlPanel1.SetHtmlFromStr(testCase.html);
  end else
  begin
    Memo1.Lines.Clear;
    SynEdit1.Lines.Clear;
    IpHtmlPanel1.SetHtml(nil);
  end;
end;

procedure TForm1.PopulateTests;
var
  node, node1: TTreeNode;
begin
  TreeView1.Items.BeginUpdate;
  try
    TreeView1.Items.Clear;
      
    node := TreeView1.Items.AddChild(nil, 'Text background');
    AddTest(node, TextWithBackgroundInBODY_title, TextWithBackgroundInBODY_descr, TextWithBackgroundInBODY_html);
    AddTest(node, TextWithBackgroundInBODY_CSS_title, TextWithBackgroundInBODY_CSS_descr, TextWithBackgroundInBODY_CSS_html);
    AddTest(node, TextInColoredTableCell_title, TextInColoredTableCell_descr, TextInColoredTableCell_html);
    node.Expanded := true;
    
    node := TreeView1.Items.AddChild(nil, 'Tables');
    node1 := TreeView1.Items.AddChild(node, 'Text alignment');
    AddTest(node1, AlignInCell_title, AlignInCell_descr, AlignInCell_html);
    AddTest(node1, AlignInCellBold_title, AlignInCellBold_descr, AlignInCellBold_html);
    AddTest(node1, AlignInCell_CSS_title, AlignInCell_CSS_descr, AlignInCell_CSS_html);
    AddTest(node1, AlignInCellBold_CSS_title, AlignInCellBold_CSS_descr, AlignInCellBold_CSS_html);
    node1.Expanded := true;
    node1 := TreeView1.Items.AddChild(node, 'Background colors');
    AddTest(node1, TableCellBkColor_title, TableCellBkColor_descr, TableCellBkColor_html);
    AddTest(node1, TableCellBkColor_style_title, TableCellBkColor_style_descr, TableCellBkColor_style_html);
    AddTest(node1, TableRowBkColor_title, TableRowBkColor_descr, TableRowBkColor_html);
    AddTest(node1, TableRowBkColor_style_title, TableRowBkColor_style_descr, TableRowBkColor_style_html);
    AddTest(node1, TableColBkColor_style_title, TableColBkColor_style_descr, TableColBkColor_style_html);
    node1.Expanded := true;
    node1 := TreeView1.Items.AddChild(node, 'Merged cells');
    AddTest(node1, TableColSpan_title, TableColSpan_descr, TableColSpan_html);
    AddTest(node1, TableRowSpan_title, TableRowSpan_descr, TableRowSpan_html);
    node1.Expanded := true;
    node1 := TreeView1.Items.AddChild(node, 'Column widths');
    AddTest(node1, ColWidth_auto_title, ColWidth_auto_descr, ColWidth_auto_html);
    AddTest(node1, ColWidth_fixed_title, ColWidth_fixed_descr, ColWidth_fixed_html);
    AddTest(node1, ColWidth_100perc_title, ColWidth_100perc_descr, ColWidth_100perc_html);
    AddTest(node1, ColWidth_30perc_70perc_title, ColWidth_30perc_70perc_descr, ColWidth_30perc_70perc_html);
    AddTest(node1, ColWidth_200px_total100perc_title, ColWidth_200px_total100perc_descr, ColWidth_200px_total100perc_html);
    AddTest(node1, ColGroup_ColWidth_200px_total100perc_title, ColGroup_ColWidth_200px_total100perc_descr, ColGroup_ColWidth_200px_total100perc_html);
    node1.Expanded := true;
    node.Expanded := true;
    
    node := TreeView1.Items.AddChild(nil, 'Lists');
    AddTest(node, OL_title, OL_descr, OL_html);
    AddTest(node, UL_title, UL_descr, UL_html);
    AddTest(node, UL_style_title, UL_style_descr, UL_style_html);
    AddTest(node, UL_3lev_title, UL_3lev_descr, UL_3lev_html);
    AddTest(node, OUL_3lev_title, OUL_3lev_descr, OUL_3lev_html);
    node.Expanded := true;
    
    node := TreeView1.Items.AddChild(nil, 'CSS');
    AddTest(node, HTMLCommentInCSS_title, HTMLCommentInCSS_descr, HTMLCommentInCSS_html);
    node.Expanded := true;
    
    node := TreeView1.Items.AddChild(nil, 'Special tags');
    node1 := TreeView1.Items.AddChild(node, '<BR>');
    AddTest(node1, BRinBODY_title, BRinBODY_descr, BRinBODY_html);
    AddTest(node1, TwoBRinBODY_title, TwoBRinBODY_descr, TwoBRinBODY_html);
    AddTest(node1, BRinP_title, BRinP_descr, BRinP_html);
    AddTest(node1, TwoBRinP_title, TwoBRinP_descr, TwoBRinP_html);
    AddTest(node1, BRinTableCell_title, BRinTableCell_descr, BRinTableCell_html);
    AddTest(node1, TwoBRinTableCell_title, TwoBRinTableCell_descr, TwoBRinTableCell_html);
    AddTest(node1, BRbetweenTwoP_title, BRbetweenTwoP_descr, BRbetweenTwoP_html);
    AddTest(node1, BRbetweenTwoTables_title, BRbetweenTwoTables_descr, BRbetweenTwoTables_html);
    node1.Expanded := true;
    node1 := TreeView1.Items.AddChild(node, '<PRE>');
    AddTest(node1, PRE_title, PRE_descr, PRE_html);
    node1.Expanded := true;
    node.Expanded := true;

    node := TreeView1.Items.AddChild(nil, 'Special cases in file structure');
    AddTest(node, NoHtmlTag_title, NoHtmlTag_descr, NoHtmlTag_html);
    AddTest(node, NoBodyTag_title, NoBodyTag_descr, NoBodyTag_html);
    node.Expanded := true;
    
    node := TreeView1.Items.AddChild(nil, 'Localization, right-to-left');
    AddTest(node, Arab_title, Arab_descr, Arab_html);
    node.Expanded := true;
    
  finally
    TreeView1.Items.EndUpdate;
  end;
end;

end.

