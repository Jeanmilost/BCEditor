unit BCEditor.Lines;

interface {********************************************************************}

uses
  SysUtils, Classes, Generics.Collections, RegularExpressions,
  Graphics, Controls,
  BCEditor.Utils, BCEditor.Consts, BCEditor.Types;

type
  TBCEditorLines = class(TStrings)
  protected type
    TCompare = function(Lines: TBCEditorLines; Line1, Line2: Integer): Integer;

    TOption = (loTrimTrailingSpaces, loTrimTrailingLines,
      loUndoGrouped, loUndoAfterLoad, loUndoAfterSave);
    TOptions = set of TOption;

    TState = set of (lsLoading, lsSaving, lsDontTrim, lsUndo, lsRedo,
      lsCaretMoved, lsSelChanged, lsTextChanged, lsInserting);

    TLine = packed record
    type
      TFlags = set of (lfHasTabs);
      TState = (lsLoaded, lsModified, lsSaved);
    public
      Background: TColor;
      CodeFolding: packed record
        BeginRange: Pointer;
        EndRange: Pointer;
        TreeLine: Boolean;
      end;
      FirstRow: Integer;
      Flags: TFlags;
      Foreground: TColor;
      Range: Pointer;
      State: TLine.TState;
      Text: string;
    end;
    TItems = TList<TLine>;

    TSearch = class
    private
      FArea: TBCEditorLinesArea;
      FBackwards: Boolean;
      FCaseSensitive: Boolean;
      FEngine: (eNormal, eLinesRegExpr, eTextRegExpr);
      FErrorMessage: string;
      FFoundLength: Integer;
      FFoundPosition: TBCEditorLinesPosition;
      FLines: TBCEditorLines;
      FPattern: string;
      FRegEx: TRegEx;
      FRegExOptions: TRegexOptions;
      FReplaceText: string;
      FWholeWords: Boolean;
      function FindLinesRegEx(const APosition: TBCEditorLinesPosition; const AFoundLength: Integer): Boolean;
      function FindNormal(const APosition: TBCEditorLinesPosition; const AFoundLength: Integer): Boolean;
      function FindTextRegEx(const APosition: TBCEditorLinesPosition; const AFoundLength: Integer): Boolean;
    protected
      property Lines: TBCEditorLines read FLines;
    public
      constructor Create(const ALines: TBCEditorLines;
        const AArea: TBCEditorLinesArea;
        const ACaseSensitive, AWholeWords, ARegExpr, ABackwards: Boolean;
        const APattern: string; const AReplaceText: string = '');
      function Find(var APosition: TBCEditorLinesPosition; out AFoundLength: Integer): Boolean;
      procedure Replace();
      property Area: TBCEditorLinesArea read FArea;
      property ErrorMessage: string read FErrorMessage;
    end;

    TUndoItem = packed record
    type
      TType = (utSelection, utInsert, utReplace, utBackspace, utDelete,
        utClear, utInsertIndent, utDeleteIndent);
    public
      BlockNumber: Integer;
      UndoType: TType;
      CaretPosition: TBCEditorLinesPosition;
      SelArea: TBCEditorLinesArea;
      Area: TBCEditorLinesArea;
      Text: string;
      function ToString(): string;
    end;

  public type
    TChangeEvent = procedure(Sender: TObject; const Line: Integer) of object;
    TUndoList = class(TList<TUndoItem>)
    strict private
      FBlockNumber: Integer;
      FChanges: Integer;
      FCurrentBlockNumber: Integer;
      FGroupBreak: Boolean;
      FLines: TBCEditorLines;
      FUpdateCount: Integer;
      function GetUpdated(): Boolean;
    public
      procedure BeginUpdate();
      procedure Clear();
      constructor Create(const ALines: TBCEditorLines);
      procedure EndUpdate();
      procedure GroupBreak();
      function Peek(): TUndoItem;
      function Pop(): TUndoItem;
      procedure Push(const AUndoType: TUndoItem.TType;
        const ACaretPosition: TBCEditorLinesPosition; const ASelArea: TBCEditorLinesArea;
        const AArea: TBCEditorLinesArea; const AText: string = '';
        const ABlockNumber: Integer = 0); overload;
      property Changes: Integer read FChanges;
      property Lines: TBCEditorLines read FLines;
      property Updated: Boolean read GetUpdated;
      property UpdateCount: Integer read FUpdateCount;
    end;

  protected const
    BOFPosition: TBCEditorLinesPosition = ( Char: 0; Line: 0; );
  strict private const
    DefaultOptions = [loUndoGrouped];
  strict private
    FCaretPosition: TBCEditorLinesPosition;
    FCaseSensitive: Boolean;
    FEditor: TCustomControl;
    FItems: TItems;
    FModified: Boolean;
    FOldCaretPosition: TBCEditorLinesPosition;
    FOldSelArea: TBCEditorLinesArea;
    FOldUndoListCount: Integer;
    FOnAfterUpdate: TNotifyEvent;
    FOnBeforeUpdate: TNotifyEvent;
    FOnCaretMoved: TNotifyEvent;
    FOnCleared: TNotifyEvent;
    FOnDeleted: TChangeEvent;
    FOnDeleting: TChangeEvent;
    FOnInserted: TChangeEvent;
    FOnSelChange: TNotifyEvent;
    FOnUpdated: TChangeEvent;
    FOptions: TOptions;
    FReadOnly: Boolean;
    FRedoList: TUndoList;
    FSelArea: TBCEditorLinesArea;
    FSortOrder: TBCEditorSortOrder;
    FState: TState;
    FUndoList: TUndoList;
    procedure DoDelete(ALine: Integer);
    procedure DoDeleteIndent(ABeginPosition, AEndPosition: TBCEditorLinesPosition;
      const AIndentText: string);
    procedure DoDeleteText(const AArea: TBCEditorLinesArea);
    procedure DoInsertIndent(const AArea: TBCEditorLinesArea;
      const AIndentText: string);
    procedure DoInsert(ALine: Integer; const AText: string);
    function DoInsertText(APosition: TBCEditorLinesPosition;
      const AText: string): TBCEditorLinesPosition;
    procedure DoPut(ALine: Integer; const AText: string);
    procedure ExchangeItems(ALine1, ALine2: Integer);
    procedure ExecuteUndoRedo(const List: TUndoList);
    function GetArea(): TBCEditorLinesArea; inline;
    function GetBOLPosition(ALine: Integer): TBCEditorLinesPosition; inline;
    function GetCanRedo(): Boolean;
    function GetCanUndo(): Boolean;
    function GetChar(APosition: TBCEditorLinesPosition): Char;
    function GetEOFPosition(): TBCEditorLinesPosition;
    function GetEOLPosition(ALine: Integer): TBCEditorLinesPosition; inline;
    function GetLineArea(ALine: Integer): TBCEditorLinesArea; inline;
    function GetTextIn(const AArea: TBCEditorLinesArea): string;
    procedure InternalClear(const AClearUndo: Boolean); overload;
    procedure SetCaretPosition(const AValue: TBCEditorLinesPosition);
    procedure SetModified(const AValue: Boolean);
    procedure SetSelArea(AValue: TBCEditorLinesArea);
    procedure QuickSort(ALeft, ARight: Integer; ACompare: TCompare);
  protected
    procedure Backspace(AArea: TBCEditorLinesArea);
    procedure ClearUndo();
    function CompareStrings(const S1, S2: string): Integer; override;
    procedure CustomSort(const ABeginLine, AEndLine: Integer; ACompare: TCompare);
    procedure DeleteIndent(ABeginPosition, AEndPosition: TBCEditorLinesPosition;
      const AIndentText: string);
    procedure DeleteText(AArea: TBCEditorLinesArea); overload;
    function Get(ALine: Integer): string; override;
    function GetCount(): Integer; override;
    function GetTextLength(): Integer;
    function GetTextStr(): string; override;
    procedure InsertIndent(ABeginPosition, AEndPosition: TBCEditorLinesPosition;
      const AIndentText: string);
    function CharIndexOf(const APosition: TBCEditorLinesPosition): Integer;
    function InsertText(APosition: TBCEditorLinesPosition;
      const AText: string): TBCEditorLinesPosition; overload;
    function IsWordBreakChar(const AChar: Char): Boolean; inline;
    function PositionOf(const ACharIndex: Integer): TBCEditorLinesPosition; overload; inline;
    function PositionOf(const ACharIndex: Integer;
      const ARelativePosition: TBCEditorLinesPosition): TBCEditorLinesPosition; overload;
    procedure Put(ALine: Integer; const AText: string); override;
    procedure Redo(); inline;
    function ReplaceText(const AArea: TBCEditorLinesArea; const AText: string): TBCEditorLinesPosition;
    procedure SetBackground(const ALine: Integer; const AValue: TColor); inline;
    procedure SetCodeFoldingBeginRange(const ALine: Integer; const AValue: Pointer);
    procedure SetCodeFoldingEndRange(const ALine: Integer; const AValue: Pointer);
    procedure SetCodeFoldingTreeLine(const ALine: Integer; const AValue: Boolean);
    procedure SetFirstRow(const ALine: Integer; const AValue: Integer); inline;
    procedure SetForeground(const ALine: Integer; const AValue: TColor); inline;
    procedure SetRange(const ALine: Integer; const AValue: Pointer); inline;
    procedure SetTextStr(const AValue: string); override;
    procedure SetUpdateState(AUpdating: Boolean); override;
    procedure Sort(const ABeginLine, AEndLine: Integer); virtual;
    procedure Undo(); inline;
    procedure UndoGroupBreak();
    function ValidPosition(const APosition: TBCEditorLinesPosition): Boolean;
    property Area: TBCEditorLinesArea read GetArea;
    property BOLPosition[Line: Integer]: TBCEditorLinesPosition read GetBOLPosition;
    property CanRedo: Boolean read GetCanRedo;
    property CanUndo: Boolean read GetCanUndo;
    property CaretPosition: TBCEditorLinesPosition read FCaretPosition write SetCaretPosition;
    property CaseSensitive: Boolean read FCaseSensitive write FCaseSensitive default False;
    property Char[Position: TBCEditorLinesPosition]: Char read GetChar;
    property Editor: TCustomControl read FEditor write FEditor;
    property EOFPosition: TBCEditorLinesPosition read GetEOFPosition;
    property EOLPosition[ALine: Integer]: TBCEditorLinesPosition read GetEOLPosition;
    property Items: TItems read FItems;
    property Modified: Boolean read FModified write SetModified;
    property LineArea[Line: Integer]: TBCEditorLinesArea read GetLineArea;
    property OnAfterUpdate: TNotifyEvent read FOnAfterUpdate write FOnAfterUpdate;
    property OnBeforeUpdate: TNotifyEvent read FOnBeforeUpdate write FOnBeforeUpdate;
    property OnCaretMoved: TNotifyEvent read FOnCaretMoved write FOnCaretMoved;
    property OnCleared: TNotifyEvent read FOnCleared write FOnCleared;
    property OnDeleted: TChangeEvent read FOnDeleted write FOnDeleted;
    property OnDeleting: TChangeEvent read FOnDeleting write FOnDeleting;
    property OnInserted: TChangeEvent read FOnInserted write FOnInserted;
    property OnSelChange: TNotifyEvent read FOnSelChange write FOnSelChange;
    property OnUpdated: TChangeEvent read FOnUpdated write FOnUpdated;
    property Options: TOptions read FOptions write FOptions;
    property ReadOnly: Boolean read FReadOnly write FReadOnly;
    property RedoList: TUndoList read FRedoList;
    property SelArea: TBCEditorLinesArea read FSelArea write SetSelArea;
    property SortOrder: TBCEditorSortOrder read FSortOrder write FSortOrder;
    property State: TState read FState;
    property TextIn[const Area: TBCEditorLinesArea]: string read GetTextIn;
    property UndoList: TUndoList read FUndoList;
  public
    function Add(const AText: string): Integer; override;
    procedure Clear(); overload; override;
    constructor Create(const AEditor: TCustomControl);
    procedure Delete(ALine: Integer); overload; override;
    destructor Destroy; override;
    procedure Insert(ALine: Integer; const AText: string); override;
    procedure SaveToStream(AStream: TStream; AEncoding: TEncoding = nil); override;
  end;

implementation {***************************************************************}

uses
  Windows,
  Math, StrUtils, SysConst;

resourcestring
  SBCEditorCharIndexInLineBreak = 'Character index is inside line break (%d)';
  SBCEditorPatternContainsWordBreakChar = 'Pattern contains word break character';

function HasLineBreak(const AText: string): Boolean;
var
  LEndPos: PChar;
  LPos: PChar;
begin
  LPos := PChar(AText); LEndPos := PChar(@AText[Length(AText)]);
  while (LPos <= LEndPos) do
    if (CharInSet(LPos^, [BCEDITOR_LINEFEED, BCEDITOR_CARRIAGE_RETURN])) then
      Exit(True)
    else
      Inc(LPos);
  Result := False;
end;

{ TBCEditorLines.TSearch ******************************************************}

constructor TBCEditorLines.TSearch.Create(const ALines: TBCEditorLines;
  const AArea: TBCEditorLinesArea;
  const ACaseSensitive, AWholeWords, ARegExpr, ABackwards: Boolean;
  const APattern: string; const AReplaceText: string = '');
var
  LIndex: Integer;
begin
  Assert((BOFPosition <= AArea.BeginPosition) and (AArea.BeginPosition <= AArea.EndPosition) and (AArea.EndPosition <= ALines.EOFPosition));

  inherited Create();

  FLines := ALines;

  FArea := AArea;
  FCaseSensitive := ACaseSensitive;
  FWholeWords := AWholeWords;
  if (not ARegExpr) then
    FEngine := eNormal
  else if (Pos(ReplaceStr(ReplaceStr(Lines.LineBreak, #13, '\r'), #10, '\n'), APattern) > 0) then
    FEngine := eTextRegExpr
  else
    FEngine := eLinesRegExpr;
  FBackwards := ABackwards;
  if (FCaseSensitive or (FEngine <> eNormal)) then
    FPattern := APattern
  else
  begin
    // Since we modify FPattern with CharLowerBuff, we need a copy of the
    // string - not only a copy of the pointer to the string...
    FPattern := Copy(APattern, 1, Length(APattern));
    CharLowerBuff(PChar(FPattern), Length(FPattern));
  end;
  FReplaceText := AReplaceText;

  if (FEngine = eNormal) then
  begin
    if (FWholeWords) then
      for LIndex := 1 to Length(FPattern) do
        if (FLines.IsWordBreakChar(FPattern[LIndex])) then
        begin
          FErrorMessage := SBCEditorPatternContainsWordBreakChar;
          FPattern := '';
          break;
        end;
  end
  else
  begin
    FRegExOptions := [roSingleLine, roCompiled];
    {$if CompilerVersion > 26}
    Include(FRegExOptions, roNotEmpty);
    {$endif}
    if (FCaseSensitive) then
      Exclude(FRegExOptions, roIgnoreCase)
    else
      Include(FRegExOptions, roIgnoreCase);
    FRegEx := TRegEx.Create(FPattern, FRegExOptions);
  end;
end;

function TBCEditorLines.TSearch.Find(var APosition: TBCEditorLinesPosition;
  out AFoundLength: Integer): Boolean;
begin
  Assert((FArea.BeginPosition <= APosition) and (APosition <= FArea.EndPosition));

  case (FEngine) of
    eNormal: Result := FindNormal(APosition, AFoundLength);
    eLinesRegExpr: Result := FindLinesRegEx(APosition, AFoundLength);
    eTextRegExpr: Result := FindTextRegEx(APosition, AFoundLength);
    else raise ERangeError.Create('FEngine: ' + IntToStr(Ord(FEngine)));
  end;

  if (FBackwards) then
    Result := Result and (FFoundPosition >= FArea.BeginPosition)
  else
    Result := Result and (FFoundPosition <= FArea.EndPosition);

  if (Result) then
  begin
    APosition := FFoundPosition;
    AFoundLength := FFoundLength;
  end;
end;

function TBCEditorLines.TSearch.FindLinesRegEx(const APosition: TBCEditorLinesPosition;
  const AFoundLength: Integer): Boolean;
var
  LMatch: TMatch;
begin
  FFoundPosition := APosition;

  Result := False;
  if (FBackwards) then
    while (not Result and (FFoundPosition.Line >= 0)) do
    begin
      try
        LMatch := FRegEx.Match(FLines[FFoundPosition.Line]);
      except
        on E: Exception do
          FErrorMessage := E.Message;
      end;

      Result := (FErrorMessage = '') and LMatch.Success and (LMatch.Index - 1 < FFoundPosition.Char);
      while (Result and LMatch.Success) do
      begin
        FFoundPosition.Char := LMatch.Index - 1;
        LMatch := LMatch.NextMatch();
      end;

      if (not Result) then
        if (FFoundPosition.Line = 0) then
          FFoundPosition := LinesPosition(0, -1)
        else
          FFoundPosition := FLines.EOLPosition[FFoundPosition.Line - 1];
    end
  else
    while (not Result and (FFoundPosition.Line < FLines.Count)) do
    begin
      try
        LMatch := FRegEx.Match(FLines[FFoundPosition.Line]);
        while (LMatch.Success and (LMatch.Index - 1 < FFoundPosition.Char)) do
          LMatch := LMatch.NextMatch();
      except
        on E: Exception do
          FErrorMessage := E.Message;
      end;

      Result := (FErrorMessage = '') and LMatch.Success;
      if (Result) then
        FFoundPosition.Char := LMatch.Index - 1
      else
        FFoundPosition := FLines.BOLPosition[FFoundPosition.Line + 1];
    end;

  if (Result) then
    FFoundLength := LMatch.Length;
end;

function TBCEditorLines.TSearch.FindNormal(const APosition: TBCEditorLinesPosition;
  const AFoundLength: Integer): Boolean;
var
  LLineLength: Integer;
  LLinePos: PChar;
  LLineText: string;
  LPatternEndPos: PChar;
  LPatternLength: Integer;
  LPatternPos: PChar;
begin
  LPatternLength := Length(FPattern);

  if (LPatternLength = 0) then
    Result := False
  else
  begin
    Result := False;

    FFoundPosition := APosition;

    while (not Result
      and (FBackwards and (FFoundPosition >= FLines.BOFPosition)
        or not FBackwards and (FFoundPosition <= FLines.EOFPosition))) do
    begin
      LLineLength := Length(FLines.Items[FFoundPosition.Line].Text);

      if (LLineLength > 0) then
      begin
        if (FCaseSensitive) then
          LLineText := FLines.Items[FFoundPosition.Line].Text
        else
        begin
          // Since we modify LLineText with CharLowerBuff, we need a copy of the
          // string - not only a copy of the pointer to the string...
          LLineText := Copy(FLines.Items[FFoundPosition.Line].Text, 1, LLineLength);
          CharLowerBuff(PChar(LLineText), Length(LLineText));
        end;

        if (FBackwards and (FFoundPosition.Char = Length(LLineText))) then
          Dec(FFoundPosition.Char);

        while (not Result
          and (FBackwards and (FFoundPosition.Char >= 0)
            or not FBackwards and (FFoundPosition.Char + LPatternLength <= LLineLength))) do
        begin
          LLinePos := @LLineText[1 + FFoundPosition.Char];

          if (not FWholeWords or not FLines.IsWordBreakChar(LLinePos^)) then
          begin
            LPatternPos := @FPattern[1];
            LPatternEndPos := @FPattern[LPatternLength];
            while ((LPatternPos <= LPatternEndPos)
              and (LPatternPos^ = LLinePos^)) do
            begin
              Inc(LPatternPos);
              Inc(LLinePos);
            end;
            Result := LPatternPos > LPatternEndPos;
          end;

          if (not Result) then
            if (FBackwards) then
              Dec(FFoundPosition.Char)
            else
              Inc(FFoundPosition.Char);
        end;
      end;

      if (not Result) then
        if (FBackwards) then
        begin
          if (FFoundPosition.Line = 0) then
            FFoundPosition := LinesPosition(0, -1)
          else
            FFoundPosition := FLines.EOLPosition[FFoundPosition.Line - 1];
        end
        else
          FFoundPosition := FLines.BOLPosition[FFoundPosition.Line + 1];
    end;

    if (Result) then
      FFoundLength := LPatternLength;
  end;
end;

function TBCEditorLines.TSearch.FindTextRegEx(const APosition: TBCEditorLinesPosition;
  const AFoundLength: Integer): Boolean;
var
  LFoundPosition: Integer;
  LInput: string;
  LMatch: TMatch;
begin
  FFoundPosition := APosition;

  LInput := Lines.Text;
  LFoundPosition := Lines.CharIndexOf(FFoundPosition);

  if (FBackwards) then
  begin
    try
      LMatch := FRegEx.Match(LInput);
    except
      on E: Exception do
        FErrorMessage := E.Message;
    end;

    Result := (FErrorMessage = '') and LMatch.Success and (LMatch.Index - 1 < LFoundPosition);
    while (Result and LMatch.Success) do
    begin
      LFoundPosition := LMatch.Index - 1;
      LMatch := LMatch.NextMatch();
    end;
  end
  else
  begin
    try
      LMatch := FRegEx.Match(LInput);
      while (LMatch.Success and (LMatch.Index - 1 < LFoundPosition)) do
        LMatch := LMatch.NextMatch();
    except
      on E: Exception do
        FErrorMessage := E.Message;
    end;

    Result := (FErrorMessage = '') and LMatch.Success;
    if (Result) then
      LFoundPosition := LMatch.Index - 1
    else
      LFoundPosition := Length(LInput);
  end;

  if (Result) then
  begin
    FFoundPosition := Lines.PositionOf(LFoundPosition);
    FFoundLength := LMatch.Length;
  end;
end;

procedure TBCEditorLines.TSearch.Replace();
var
  LEndPosition: TBCEditorLinesPosition;
begin
  Assert((BOFPosition <= FFoundPosition) and (FFoundPosition <= FLines.EOFPosition));

  LEndPosition := FLines.PositionOf(FFoundLength, FFoundPosition);

  if (FEngine = eNormal) then
    FLines.ReplaceText(LinesArea(FFoundPosition, LEndPosition), FReplaceText)
  else if (FEngine = eLinesRegExpr) then
    Assert(False)
  else
    FLines.ReplaceText(LinesArea(FFoundPosition, LEndPosition), FRegEx.Replace(FLines.TextIn[LinesArea(FFoundPosition, LEndPosition)], FPattern, FReplaceText, FRegExOptions));
end;

{ TBCEditorLines.TUndoList ****************************************************}

function TBCEditorLines.TUndoItem.ToString(): string;
begin
  Result :=
    'BlockNumber: ' + IntToStr(BlockNumber) + #13#10
    + 'UndoType: ' + IntToStr(Ord(UndoType)) + #13#10
    + 'CaretPosition: ' + CaretPosition.ToString() + #13#10
    + 'SelArea: ' + SelArea.ToString() + #13#10
    + 'Area: ' + Area.ToString() + #13#10
    + 'Text: ' + Text;
end;

{ TBCEditorLines.TUndoList ****************************************************}

procedure TBCEditorLines.TUndoList.BeginUpdate();
begin
  if (UpdateCount = 0) then
  begin
    Inc(FBlockNumber);
    FChanges := 0;
    FCurrentBlockNumber := FBlockNumber;
  end;

  Inc(FUpdateCount);
end;

procedure TBCEditorLines.TUndoList.Clear();
begin
  inherited;

  FBlockNumber := 0;
  FGroupBreak := False;
end;

constructor TBCEditorLines.TUndoList.Create(const ALines: TBCEditorLines);
begin
  inherited Create();

  FLines := ALines;

  FBlockNumber := 0;
  FUpdateCount := 0;
end;

procedure TBCEditorLines.TUndoList.EndUpdate();
begin
  if (FUpdateCount > 0) then
  begin
    Dec(FUpdateCount);

    if (FUpdateCount = 0) then
    begin
      FChanges := 0;
      FCurrentBlockNumber := 0;
    end;
  end;
end;

function TBCEditorLines.TUndoList.GetUpdated(): Boolean;
begin
  Result := (FUpdateCount > 0) and (FChanges > 0);
end;

procedure TBCEditorLines.TUndoList.GroupBreak();
begin
  FGroupBreak := True;
end;

function TBCEditorLines.TUndoList.Peek(): TUndoItem;
begin
  Assert(Count > 0);

  Result := List[Count - 1];
end;

function TBCEditorLines.TUndoList.Pop(): TUndoItem;
begin
  Result := Peek();
  Delete(Count - 1);
end;

procedure TBCEditorLines.TUndoList.Push(const AUndoType: TUndoItem.TType;
  const ACaretPosition: TBCEditorLinesPosition; const ASelArea: TBCEditorLinesArea;
  const AArea: TBCEditorLinesArea; const AText: string = '';
  const ABlockNumber: Integer = 0);
var
  LHandled: Boolean;
  LItem: TUndoItem;
begin
  if (not (lsLoading in Lines.State)) then
  begin
    LHandled := False;
    if ((Lines.State * [lsUndo, lsRedo] = [])
      and (loUndoGrouped in Lines.Options)
      and not FGroupBreak
      and (Count > 0) and (List[Count - 1].UndoType = AUndoType)) then
      case (AUndoType) of
        utSelection: LHandled := True; // Ignore
        utInsert:
          if (List[Count - 1].Area.EndPosition = AArea.BeginPosition) then
          begin
            List[Count - 1].Area.EndPosition := AArea.EndPosition;
            LHandled := True;
          end;
        utReplace:
          if (List[Count - 1].Area.EndPosition = AArea.BeginPosition) then
          begin
            List[Count - 1].Area.EndPosition := AArea.EndPosition;
            List[Count - 1].Text := List[Count - 1].Text + AText;
            LHandled := True;
          end;
        utBackspace:
          if (List[Count - 1].Area.BeginPosition = AArea.EndPosition) then
          begin
            List[Count - 1].Area.BeginPosition := AArea.BeginPosition;
            List[Count - 1].Text := AText + List[Count - 1].Text;
            LHandled := True;
          end;
        utDelete:
          if (List[Count - 1].Area.EndPosition = AArea.BeginPosition) then
          begin
            List[Count - 1].Area.EndPosition := AArea.EndPosition;
            List[Count - 1].Text := List[Count - 1].Text + AText;
            LHandled := True;
          end;
      end;

    if (not LHandled) then
    begin
      if (ABlockNumber > 0) then
        LItem.BlockNumber := ABlockNumber
      else if (FCurrentBlockNumber > 0) then
        LItem.BlockNumber := FCurrentBlockNumber
      else
      begin
        Inc(FBlockNumber);
        LItem.BlockNumber := FBlockNumber;
      end;
      LItem.Area := AArea;
      LItem.CaretPosition := ACaretPosition;
      LItem.SelArea := ASelArea;
      LItem.Text := AText;
      LItem.UndoType := AUndoType;
      Add(LItem);
    end;

    if (UpdateCount > 0) then
      Inc(FChanges);
    FGroupBreak := False;
  end;
end;

{ TBCEditorLines **************************************************************}

function CompareLines(ALines: TBCEditorLines; AIndex1, AIndex2: Integer): Integer;
begin
  Result := ALines.CompareStrings(ALines.Items[AIndex1].Text, ALines.Items[AIndex2].Text);
  if (ALines.SortOrder = soDesc) then
    Result := - Result;
end;

function TBCEditorLines.Add(const AText: string): Integer;
begin
  Result := Count;
  Insert(Count, AText);
end;

procedure TBCEditorLines.Backspace(AArea: TBCEditorLinesArea);
var
  LCaretPosition: TBCEditorLinesPosition;
  LSelArea: TBCEditorLinesArea;
  LText: string;
begin
  Assert((BOFPosition <= AArea.BeginPosition) and (AArea.BeginPosition < AArea.EndPosition) and (AArea.EndPosition <= EOFPosition));

  LCaretPosition := CaretPosition;
  LSelArea := SelArea;

  LText := TextIn[AArea];

  BeginUpdate();
  try
    DoDeleteText(AArea);

    UndoList.Push(utBackspace, LCaretPosition, LSelArea,
      AArea, LText);
  finally
    EndUpdate();
  end;

  CaretPosition := AArea.BeginPosition;
end;

procedure TBCEditorLines.Clear();
begin
  InternalClear(True);
end;

procedure TBCEditorLines.ClearUndo();
begin
  UndoList.Clear();
  RedoList.Clear();
end;

function TBCEditorLines.CompareStrings(const S1, S2: string): Integer;
begin
  if CaseSensitive then
    Result := CompareStr(S1, S2)
  else
    Result := CompareText(S1, S2);

  if SortOrder = soDesc then
    Result := -1 * Result;
end;

constructor TBCEditorLines.Create(const AEditor: TCustomControl);
begin
  inherited Create();

  FEditor := AEditor;

  FCaretPosition := BOFPosition;
  FCaseSensitive := False;
  FItems := TItems.Create();
  FModified := False;
  FOnAfterUpdate := nil;
  FOnBeforeUpdate := nil;
  FOnCaretMoved := nil;
  FOnCleared := nil;
  FOnDeleted := nil;
  FOnDeleting := nil;
  FOnInserted := nil;
  FOnSelChange := nil;
  FOnUpdated := nil;
  FOptions := DefaultOptions;
  FRedoList := TUndoList.Create(Self);
  FReadOnly := False;
  FSelArea.BeginPosition := BOFPosition;
  FSelArea.EndPosition := BOFPosition;
  FState := [];
  FUndoList := TUndoList.Create(Self);
end;

procedure TBCEditorLines.CustomSort(const ABeginLine, AEndLine: Integer;
  ACompare: TCompare);
var
  LArea: TBCEditorLinesArea;
  LText: string;
begin
  BeginUpdate();
  BeginUpdate();

  try
    if (AEndLine < Count - 1) then
      LArea := LinesArea(BOLPosition[ABeginLine], BOLPosition[ABeginLine + 1])
    else
      LArea := LinesArea(BOLPosition[ABeginLine], LinesPosition(Length(Items[AEndLine].Text), AEndLine));

    LText := TextIn[LArea];
    UndoList.Push(utDelete, CaretPosition, SelArea,
      LinesArea(LArea.BeginPosition, InvalidLinesPosition), LText);

    QuickSort(ABeginLine, AEndLine, ACompare);

    UndoList.Push(utInsert, InvalidLinesPosition, InvalidLinesArea,
      LArea);
  finally
    EndUpdate();
    EndUpdate();
    RedoList.Clear();
  end;
end;

procedure TBCEditorLines.Delete(ALine: Integer);
var
  LBeginPosition: TBCEditorLinesPosition;
  LCaretPosition: TBCEditorLinesPosition;
  LSelArea: TBCEditorLinesArea;
  LText: string;
  LUndoType: TUndoItem.TType;
begin
  Assert((0 <= ALine) and (ALine < Count));

  LCaretPosition := CaretPosition;
  LSelArea := SelArea;
  if (Count = 1) then
  begin
    LBeginPosition := BOLPosition[ALine];
    LText := Items[ALine].Text;
    LUndoType := utClear;
  end
  else if (ALine < Count - 1) then
  begin
    LBeginPosition := BOLPosition[ALine];
    LText := Items[ALine].Text + LineBreak;
    LUndoType := utDelete;
  end
  else
  begin
    LBeginPosition := EOLPosition[ALine - 1];
    LText := LineBreak + Items[ALine].Text;
    LUndoType := utDelete;
  end;

  BeginUpdate();
  try
    DoDelete(ALine);

    UndoList.Push(LUndoType, LCaretPosition, LSelArea,
      LinesArea(LBeginPosition, InvalidLinesPosition), LText);
  finally
    EndUpdate();
  end;
end;

procedure TBCEditorLines.DeleteIndent(ABeginPosition, AEndPosition: TBCEditorLinesPosition;
  const AIndentText: string);
var
  LArea: TBCEditorLinesArea;
  LCaretPosition: TBCEditorLinesPosition;
  LLine: Integer;
  LIndentFound: Boolean;
  LIndentTextLength: Integer;
  LSelArea: TBCEditorLinesArea;
begin
  LArea := LinesArea(Min(ABeginPosition, AEndPosition), Max(ABeginPosition, AEndPosition));

  Assert((BOFPosition <= LArea.BeginPosition) and (LArea.EndPosition <= EOFPosition));

  LIndentTextLength := Length(AIndentText);
  LIndentFound := LArea.BeginPosition.Line <> LArea.EndPosition.Line;
  for LLine := LArea.BeginPosition.Line to LArea.EndPosition.Line do
    if (Copy(Items[LLine].Text, 1 + LArea.BeginPosition.Char, LIndentTextLength) <> AIndentText) then
    begin
      LIndentFound := False;
      break;
    end;

  if (LIndentFound) then
  begin
    LCaretPosition := CaretPosition;
    LSelArea := SelArea;

    DoDeleteIndent(LArea.BeginPosition, LArea.EndPosition, AIndentText);

    UndoList.Push(utDeleteIndent, LCaretPosition, LSelArea,
      LArea, AIndentText);

    RedoList.Clear();
  end
  else
  begin
    BeginUpdate();

    try
      for LLine := LArea.BeginPosition.Line to LArea.EndPosition.Line do
        if (LeftStr(Items[LLine].Text, LIndentTextLength) = AIndentText) then
          DeleteText(LinesArea(BOLPosition[LLine], LinesPosition(Length(AIndentText), LLine)));
    finally
      EndUpdate();
    end;
  end;

  if ((ABeginPosition <= CaretPosition) and (CaretPosition <= AEndPosition)
    and (CaretPosition.Char > Length(Items[CaretPosition.Line].Text))) then
    FCaretPosition.Char := Length(Items[CaretPosition.Line].Text);
  if (FSelArea.Containts(ABeginPosition) and FSelArea.Containts(AEndPosition))
    and (CaretPosition.Char > Length(Items[FSelArea.BeginPosition.Line].Text)) then
    FSelArea.BeginPosition.Char := Length(Items[SelArea.BeginPosition.Line].Text);
  if ((ABeginPosition <= FSelArea.EndPosition) and (FSelArea.EndPosition <= AEndPosition)
    and (FSelArea.EndPosition.Char > Length(Items[FSelArea.EndPosition.Line].Text))) then
    FSelArea.EndPosition.Char := Length(Items[SelArea.EndPosition.Line].Text);
end;

procedure TBCEditorLines.DeleteText(AArea: TBCEditorLinesArea);
var
  LCaretPosition: TBCEditorLinesPosition;
  LInsertArea: TBCEditorLinesArea;
  LSelArea: TBCEditorLinesArea;
  LText: string;
begin
  BeginUpdate();
  try
    if (AArea.IsEmpty()) then
      // Do nothing
    else
    begin
      LCaretPosition := CaretPosition;
      LSelArea := SelArea;

      if (AArea.BeginPosition.Char > Length(Items[AArea.BeginPosition.Line].Text)) then
      begin
        LInsertArea.BeginPosition := EOLPosition[AArea.BeginPosition.Line];

        LInsertArea.EndPosition := DoInsertText(LInsertArea.BeginPosition, StringOfChar(BCEDITOR_SPACE_CHAR, AArea.BeginPosition.Char - LInsertArea.BeginPosition.Char));

        UndoList.Push(utInsert, LCaretPosition, LSelArea,
          LInsertArea);

        Assert(LInsertArea.EndPosition = AArea.BeginPosition);
      end;

      LText := TextIn[AArea];

      DoDeleteText(AArea);

      UndoList.Push(utDelete, LCaretPosition, LSelArea,
        LinesArea(AArea.BeginPosition, InvalidLinesPosition), LText);
    end;

    CaretPosition := AArea.BeginPosition;
  finally
    EndUpdate();
  end;

  RedoList.Clear();
end;

destructor TBCEditorLines.Destroy;
begin
  FItems.Free();
  FRedoList.Free();
  FUndoList.Free();

  inherited;
end;

procedure TBCEditorLines.DoDelete(ALine: Integer);
begin
  Assert((0 <= ALine) and (ALine < Count));

  if (Assigned(OnDeleting)) then
    OnDeleting(Self, ALine);

  Items.Delete(ALine);

  if (Count = 0) then
    CaretPosition := BOFPosition
  else if (ALine < Count) then
    CaretPosition := BOLPosition[ALine]
  else
    CaretPosition := EOLPosition[ALine - 1];

  if (UpdateCount > 0) then
    Include(FState, lsTextChanged);

  if ((Count = 0) and Assigned(OnCleared)) then
    OnCleared(Self)
  else if (Assigned(OnDeleted)) then
    OnDeleted(Self, ALine);
end;

procedure TBCEditorLines.DoDeleteIndent(ABeginPosition, AEndPosition: TBCEditorLinesPosition;
  const AIndentText: string);
var
  LLine: Integer;
  LLinesBeginPosition: TBCEditorLinesPosition;
  LLinesEndPosition: TBCEditorLinesPosition;
begin
  Assert((BOFPosition <= ABeginPosition) and (AEndPosition <= EOFPosition));
  Assert(ABeginPosition <= AEndPosition);

  if (Count > 0) then
  begin
    LLinesBeginPosition := BOLPosition[ABeginPosition.Line];
    if (ABeginPosition = AEndPosition) then
      LLinesEndPosition := EOLPosition[AEndPosition.Line]
    else if ((AEndPosition.Char = 0) and (AEndPosition.Line > ABeginPosition.Line)) then
      LLinesEndPosition := EOLPosition[AEndPosition.Line - 1]
    else
      LLinesEndPosition := AEndPosition;

    BeginUpdate();

    try
      for LLine := LLinesBeginPosition.Line to LLinesEndPosition.Line do
        if (LeftStr(Items[LLine].Text, Length(AIndentText)) = AIndentText) then
          DoPut(LLine, Copy(Items[LLine].Text, 1 + Length(AIndentText), MaxInt));
    finally
      EndUpdate();
    end;
  end;
end;

procedure TBCEditorLines.DoDeleteText(const AArea: TBCEditorLinesArea);
var
  Line: Integer;
begin
  Assert((BOFPosition <= AArea.BeginPosition) and (AArea.EndPosition <= EOFPosition));
  Assert(AArea.BeginPosition <= AArea.EndPosition);

  if (AArea.IsEmpty()) then
    // Nothing to do...
  else if (AArea.BeginPosition.Line = AArea.EndPosition.Line) then
    DoPut(AArea.BeginPosition.Line, LeftStr(Items[AArea.BeginPosition.Line].Text, AArea.BeginPosition.Char)
      + Copy(Items[AArea.EndPosition.Line].Text, 1 + AArea.EndPosition.Char, MaxInt))
  else
  begin
    BeginUpdate();

    try
      DoPut(AArea.BeginPosition.Line, LeftStr(Items[AArea.BeginPosition.Line].Text, AArea.BeginPosition.Char)
        + Copy(Items[AArea.EndPosition.Line].Text, 1 + AArea.EndPosition.Char, MaxInt));

      for Line := AArea.EndPosition.Line downto AArea.BeginPosition.Line + 1 do
        DoDelete(Line);
    finally
      EndUpdate();
    end;
  end;
end;

procedure TBCEditorLines.DoInsertIndent(const AArea: TBCEditorLinesArea;
  const AIndentText: string);
var
  LEndLine: Integer;
  LLine: Integer;
begin
  Assert((BOFPosition <= AArea.BeginPosition) and (AArea.EndPosition <= EOFPosition));
  Assert(AArea.BeginPosition <= AArea.EndPosition);

  if (Count > 0) then
  begin
    if ((AArea.EndPosition.Char = 0) and (AArea.EndPosition.Line > AArea.BeginPosition.Line)) then
      LEndLine := AArea.EndPosition.Line - 1
    else
      LEndLine := AArea.EndPosition.Line;

    BeginUpdate();
    try
      for LLine := AArea.BeginPosition.Line to LEndLine do
        DoPut(LLine, AIndentText + Items[LLine].Text);
    finally
      EndUpdate();
    end;
  end;
end;

procedure TBCEditorLines.DoInsert(ALine: Integer; const AText: string);
var
  LLine: TLine;
begin
  Assert((0 <= ALine) and (ALine <= Count));

  BeginUpdate();
  try
    LLine.Background := clNone;
    LLine.CodeFolding.BeginRange := nil;
    LLine.CodeFolding.EndRange := nil;
    LLine.CodeFolding.TreeLine := False;
    LLine.Flags := [];
    LLine.FirstRow := -1;
    LLine.Foreground := clNone;
    LLine.Range := nil;
    LLine.State := lsModified;
    LLine.Text := '';
    Items.Insert(ALine, LLine);

    Include(FState, lsInserting);
    try
      DoPut(ALine, AText);
    finally
      Exclude(FState, lsInserting);
    end;

    if (ALine < Count - 1) then
      CaretPosition := BOLPosition[ALine + 1]
    else
      CaretPosition := EOLPosition[ALine];
    SelArea := LinesArea(CaretPosition, CaretPosition);

    if (UpdateCount > 0) then
      Include(FState, lsTextChanged);
    if (Assigned(OnInserted)) then
      OnInserted(Self, ALine);
  finally
    EndUpdate();
  end;
end;

function TBCEditorLines.DoInsertText(APosition: TBCEditorLinesPosition;
  const AText: string): TBCEditorLinesPosition;
var
  LEndPos: PChar;
  LEOL: Boolean;
  LLine: Integer;
  LLineBeginPos: PChar;
  LLineBreak: array [0..2] of System.Char;
  LLineEnd: string;
  LPos: PChar;
begin
  Assert(BOFPosition <= APosition);
  Assert((APosition.Line = 0) and (Count = 0) or (APosition.Line < Count) and (APosition.Char <= Length(Items[APosition.Line].Text)),
    'APosition: ' + APosition.ToString() + #13#10
    + 'EOFPosition: ' + EOFPosition.ToString() + #13#10
    + 'Length: ' + IntToStr(Length(Items[APosition.Line].Text)));

  if (AText = '') then
    Result := APosition
  else if (not HasLineBreak(AText)) then
  begin
    if (Count = 0) then
    begin
      DoInsert(0, AText);
      Result := EOLPosition[0];
    end
    else
    begin
      DoPut(APosition.Line, LeftStr(Items[APosition.Line].Text, APosition.Char)
        + AText
        + Copy(Items[APosition.Line].Text, 1 + APosition.Char, MaxInt));
      Result := LinesPosition(APosition.Char + Length(AText), APosition.Line);
    end;
  end
  else
  begin
    LLineBreak[0] := #0; LLineBreak[1] := #0; LLineBreak[2] := #0;


    BeginUpdate();
    try
      LLine := APosition.Line;

      LPos := @AText[1];
      LEndPos := @AText[Length(AText)];

      LLineBeginPos := LPos;
      while ((LPos <= LEndPos) and not CharInSet(LPos^, [BCEDITOR_LINEFEED, BCEDITOR_CARRIAGE_RETURN])) do
        Inc(LPos);

      if (Count = 0) then
      begin
        DoInsert(0, LeftStr(AText, LPos - LLineBeginPos));
        LLine := 1;
      end
      else if (LLine < Count) then
      begin
        if (APosition.Char = 0) then
        begin
          LLineEnd := Items[LLine].Text;
          if (LLineBeginPos < LPos) then
            DoPut(LLine, LeftStr(AText, LPos - LLineBeginPos))
          else if (Items[LLine].Text <> '') then
            DoPut(LLine, '');
        end
        else
        begin
          LLineEnd := Copy(Items[LLine].Text, 1 + APosition.Char, MaxInt);
          if (LLineBeginPos < LPos) then
            DoPut(LLine, LeftStr(Items[LLine].Text, APosition.Char) + LeftStr(AText, LPos - LLineBeginPos))
          else if (Length(Items[LLine].Text) > APosition.Char) then
            DoPut(LLine, LeftStr(Items[LLine].Text, APosition.Char));
        end;
        Inc(LLine);
      end
      else
      begin
        DoInsert(LLine, LeftStr(AText, LPos - LLineBeginPos));
        Inc(LLine);
      end;

      if (LPos <= LEndPos) then
      begin
        LLineBreak[0] := LPos^;
        if ((LLineBreak[0] = BCEDITOR_CARRIAGE_RETURN) and (LPos < LEndPos) and (LPos[1] = BCEDITOR_LINEFEED)) then
          LLineBreak[1] := LPos[1];
      end;

      LEOL := (LPos <= LEndPos) and (LPos[0] = LLineBreak[0]) and ((LLineBreak[1] = #0) or (LPos < LEndPos) and (LPos[1] = LLineBreak[1]));
      while (LEOL) do
      begin
        if (LLineBreak[1] = #0) then
          Inc(LPos)
        else
          Inc(LPos, 2);
        LLineBeginPos := LPos;
        repeat
          LEOL := (LPos <= LEndPos) and (LPos[0] = LLineBreak[0]) and ((LLineBreak[1] = #0) or (LPos < LEndPos) and (LPos[1] = LLineBreak[1]));
          if (not LEOL) then
            Inc(LPos);
        until ((LPos > LEndPos) or LEOL);
        if (LEOL) then
        begin
          DoInsert(LLine, Copy(AText, 1 + LLineBeginPos - @AText[1], LPos - LLineBeginPos));
          Inc(LLine);
        end;
      end;

      if (LPos <= LEndPos) then
      begin
        DoInsert(LLine, Copy(AText, LPos - @AText[1], LEndPos + 1 - LPos) + LLineEnd);
        Result := LinesPosition(LEndPos + 1 - (LLineBeginPos + 1), LLine);
      end
      else
      begin
        DoInsert(LLine, RightStr(AText, LEndPos + 1 - LLineBeginPos) + LLineEnd);
        Result := LinesPosition(1 + LEndPos + 1 - (LLineBeginPos + 1), LLine);
      end;

    finally
      EndUpdate();

      if ((lsLoading in State) and (LLineBreak[0] <> #0)) then
        LineBreak := StrPas(PChar(@LLineBreak[0]));
    end;
  end;
end;

procedure TBCEditorLines.DoPut(ALine: Integer; const AText: string);
var
  LModified: Boolean;
  LPos: PChar;
  LEndPos: PChar;
begin
  Assert((0 <= ALine) and (ALine < Count));

  LModified := AText <> Items[ALine].Text;
  if (LModified) then
  begin
    Items.List[ALine].Flags := [];
    Items.List[ALine].State := lsModified;
    Items.List[ALine].Text := AText;

    if (AText <> '') then
    begin
      LPos := @AText[1];
      LEndPos := @AText[Length(AText)];
      while (LPos <= LEndPos) do
      begin
        if (LPos^ = BCEDITOR_TAB_CHAR) then
        begin
          Include(Items.List[ALine].Flags, lfHasTabs);
          break;
        end;
        Inc(LPos);
      end;
    end;
  end;

  CaretPosition := EOLPosition[ALine];

  if (LModified and not (lsInserting in State)) then
  begin
    if (UpdateCount > 0) then
      Include(FState, lsTextChanged);
    if (Assigned(OnUpdated)) then
      OnUpdated(Self, ALine);
  end;
end;

procedure TBCEditorLines.ExchangeItems(ALine1, ALine2: Integer);
var
  LLine: TLine;
begin
  LLine := Items[ALine1];
  Items[ALine1] := Items[ALine2];
  Items[ALine2] := LLine;
end;

var
  Progress: string;

procedure TBCEditorLines.ExecuteUndoRedo(const List: TUndoList);
var
  LPreviousBlockNumber: Integer;
  LCaretPosition: TBCEditorLinesPosition;
  LDestinationList: TUndoList;
  LEndPosition: TBCEditorLinesPosition;
  LSelArea: TBCEditorLinesArea;
  LText: string;
  LUndoItem: TUndoItem;
begin
  if (not ReadOnly and (List.Count > 0)) then
  begin
    if (List = UndoList) then
    begin
      Include(FState, lsUndo);
      LDestinationList := RedoList;

      LUndoItem := List.Peek();
      Progress := RightStr(Progress + '-U' + LUndoItem.BlockNumber.ToString(), 50);
    end
    else
    begin
      Include(FState, lsRedo);
      LDestinationList := UndoList;
      Progress := RightStr(Progress + '-R' + LUndoItem.BlockNumber.ToString(), 50);
    end;

    BeginUpdate();

    LCaretPosition := CaretPosition;
    LSelArea := SelArea;

    repeat
      LUndoItem := List.Pop();

      case (LUndoItem.UndoType) of
        utSelection:
          begin
            LDestinationList.Push(LUndoItem.UndoType, LCaretPosition, LSelArea,
              LUndoItem.Area, LUndoItem.Text, LUndoItem.BlockNumber);
          end;
        utInsert,
        utReplace,
        utBackspace,
        utDelete:
          begin
            if (not LUndoItem.Area.IsEmpty()
             and ((LUndoItem.UndoType in [utReplace])
               or ((LUndoItem.UndoType in [utBackspace, utDelete]) xor (List = UndoList)))) then
            begin
              // Debug 2017-05-03
              try
                LText := TextIn[LUndoItem.Area];
              except
                on E: Exception do
                  E.RaiseOuterException(Exception.Create(LUndoItem.ToString() + #13#10
                    + 'Progress: ' + Progress + #13#10
                    + 'LDestinationList.Count: ' + IntToStr(LDestinationList.Count) + #13#10
                    + 'Area: ' + Area.ToString() + #13#10#13#10
                    + E.ClassName + ':' + #13#10
                    + E.Message));
              end;
              DoDeleteText(LUndoItem.Area);
              if (not (LUndoItem.UndoType in [utReplace])) then
                LDestinationList.Push(LUndoItem.UndoType, LCaretPosition, LSelArea,
                  LUndoItem.Area, LText, LUndoItem.BlockNumber);
            end
            else
              LText := '';
            if ((LUndoItem.UndoType in [utReplace])
                or ((LUndoItem.UndoType in [utBackspace, utDelete]) xor (List <> UndoList))) then
            begin
              if (LUndoItem.Text = '') then
                LEndPosition := LUndoItem.Area.BeginPosition
              else
              try
                LEndPosition := DoInsertText(LUndoItem.Area.BeginPosition, LUndoItem.Text);
              except
                on E: Exception do
                  E.RaiseOuterException(EAssertionFailed.Create(LUndoItem.ToString() + #13#10
                    + 'Progress: ' + Progress + #13#10#13#10
                    + E.ClassName + ':' + #13#10
                    + E.Message));
              end;
              LDestinationList.Push(LUndoItem.UndoType, LCaretPosition, LSelArea,
                LinesArea(LUndoItem.Area.BeginPosition, LEndPosition), LText, LUndoItem.BlockNumber);
            end;
          end;
        utClear:
          if (List = RedoList) then
          begin
            LText := Text;
            InternalClear(False);
            LDestinationList.Push(LUndoItem.UndoType, LCaretPosition, LSelArea,
              LinesArea(BOFPosition, InvalidLinesPosition), LText, LUndoItem.BlockNumber);
          end
          else
          begin
            LEndPosition := DoInsertText(LUndoItem.Area.BeginPosition, LUndoItem.Text);
            LDestinationList.Push(LUndoItem.UndoType, LCaretPosition, LSelArea,
              LinesArea(LUndoItem.Area.BeginPosition, LEndPosition), '', LUndoItem.BlockNumber);
          end;
        utInsertIndent,
        utDeleteIndent:
          begin
            if ((LUndoItem.UndoType <> utInsertIndent) xor (List = UndoList)) then
              DoDeleteIndent(LUndoItem.Area.BeginPosition, LUndoItem.Area.EndPosition,
                LUndoItem.Text)
            else
              DoInsertIndent(LUndoItem.Area, LUndoItem.Text);
            LDestinationList.Push(LUndoItem.UndoType, LCaretPosition, LSelArea,
              LUndoItem.Area, LUndoItem.Text, LUndoItem.BlockNumber);
          end;
        else raise ERangeError.Create('UndoType: ' + IntToStr(Ord(LUndoItem.UndoType)));
      end;

      LCaretPosition := LUndoItem.CaretPosition;
      LSelArea := LUndoItem.SelArea;

      LPreviousBlockNumber := LUndoItem.BlockNumber;
      if (List.Count > 0) then
        LUndoItem := List.Peek();
    until ((List.Count = 0)
      or (LUndoItem.BlockNumber <> LPreviousBlockNumber));

    CaretPosition := LCaretPosition;
    SelArea := LSelArea;

    EndUpdate();

    if (List = UndoList) then
      Exclude(FState, lsUndo)
    else
      Exclude(FState, lsRedo);
  end;
end;

function TBCEditorLines.Get(ALine: Integer): string;
begin
  Assert((0 <= ALine) and (ALine < Count));

  Result := Items[ALine].Text;
end;

function TBCEditorLines.GetArea(): TBCEditorLinesArea;
begin
  Result := LinesArea(BOFPosition, EOFPosition);
end;

function TBCEditorLines.GetBOLPosition(ALine: Integer): TBCEditorLinesPosition;
begin
  Result := LinesPosition(0, ALine);
end;

function TBCEditorLines.GetCanRedo(): Boolean;
begin
  Result := RedoList.Count > 0;
end;

function TBCEditorLines.GetCanUndo(): Boolean;
begin
  Result := UndoList.Count > 0;
end;

function TBCEditorLines.GetChar(APosition: TBCEditorLinesPosition): Char;
begin
  Assert((0 <= APosition.Line) and (APosition.Line < Items.Count));
  Assert((0 <= APosition.Char) and (APosition.Char < Length(Items.List[APosition.Line].Text)));

  Result := Items[APosition.Line].Text[1 + APosition.Char];
end;

function TBCEditorLines.GetCount(): Integer;
begin
  Result := Items.Count;
end;

function TBCEditorLines.GetEOFPosition(): TBCEditorLinesPosition;
begin
  if (Count = 0) then
    Result := BOFPosition
  else
    Result := EOLPosition[Count - 1];
end;

function TBCEditorLines.GetEOLPosition(ALine: Integer): TBCEditorLinesPosition;
begin
  Assert((0 <= ALine) and (ALine < Count));

  Result := LinesPosition(Length(Items[ALine].Text), ALine)
end;

function TBCEditorLines.GetLineArea(ALine: Integer): TBCEditorLinesArea;
begin
  Result := LinesArea(BOLPosition[ALine], EOLPosition[ALine]);
end;

function TBCEditorLines.GetTextIn(const AArea: TBCEditorLinesArea): string;
var
  LEndChar: Integer;
  LEndLine: Integer;
  LLine: Integer;
  StringBuilder: TStringBuilder;
begin
  Assert((BOFPosition <= AArea.BeginPosition) and (AArea.EndPosition <= EOFPosition),
    'BOFPosition: ' + BOFPosition.ToString() + #13#10
    + 'AArea: ' + AArea.ToString() + #13#10
    + 'EOFPosition: ' + EOFPosition.ToString());
  Assert(AArea.BeginPosition <= AArea.EndPosition,
    'AArea: ' + AArea.ToString() + #13#10
    + 'Length(' + IntToStr(AArea.BeginPosition.Line) + '):' + IntToStr(Length(Items[AArea.BeginPosition.Line].Text)) + #13#10
    + 'Length(' + IntToStr(AArea.EndPosition.Line) + '):' + IntToStr(Length(Items[AArea.EndPosition.Line].Text)));

  if (Count = 0) then
  begin
    Assert((AArea.BeginPosition = BOFPosition) and AArea.IsEmpty());
    Result := '';
  end
  else
  begin
    Assert(AArea.BeginPosition.Char <= Length(Items[AArea.BeginPosition.Line].Text),
      'AArea.BeginPosition: ' + AArea.BeginPosition.ToString() + #13#10
      + 'Length: ' + IntToStr(Length(Items[AArea.EndPosition.Line].Text)));
    Assert(AArea.EndPosition.Char <= Length(Items[AArea.EndPosition.Line].Text),
      'AArea.EndPosition: ' + AArea.EndPosition.ToString() + #13#10
      + 'Length: ' + IntToStr(Length(Items[AArea.EndPosition.Line].Text)));

    LEndLine := AArea.EndPosition.Line;
    if ((loTrimTrailingLines in Options) and (lsSaving in State)) then
      while ((LEndLine > 0)
        and (Trim(Items[LEndLine].Text) = '')
        and (Trim(Items[LEndLine - 1].Text) = '')) do
        Dec(LEndLine);

    if (AArea.IsEmpty()) then
      Result := ''
    else if (AArea.BeginPosition.Line = LEndLine) then
    begin
      if (LEndLine = AArea.EndPosition.Line) then
        LEndChar := AArea.EndPosition.Char
      else
        LEndChar := Length(Items[LEndLine].Text);
      if ((loTrimTrailingSpaces in Options) and (lsSaving in State)) then
        while ((LEndChar > 0) and (Items[LEndLine].Text[1 + LEndChar - 1] = BCEDITOR_SPACE_CHAR)) do
          Dec(LEndChar);
      Result := Copy(Items[AArea.BeginPosition.Line].Text, 1 + AArea.BeginPosition.Char, LEndChar - AArea.BeginPosition.Char)
    end
    else
    begin
      StringBuilder := TStringBuilder.Create();

      LEndChar := Length(Items[AArea.BeginPosition.Line].Text);
      if ((loTrimTrailingSpaces in Options) and (lsSaving in State)) then
        while ((LEndChar > AArea.BeginPosition.Char) and (Items[AArea.BeginPosition.Line].Text[1 + LEndChar - 1] = BCEDITOR_SPACE_CHAR)) do
          Dec(LEndChar);

      // Debug 2017-05-07
      Assert(LEndChar - AArea.BeginPosition.Char >= 0,
        'LEndChar: ' + IntToStr(LEndChar) + #13#10
        + 'ABeginPosition.Char: ' + IntToStr(AArea.BeginPosition.Char) + #13#10
        + 'Length: ' + IntToStr(Length(Items[AArea.BeginPosition.Line].Text)));

      StringBuilder.Append(Items[AArea.BeginPosition.Line].Text, AArea.BeginPosition.Char, LEndChar - AArea.BeginPosition.Char);
      for LLine := AArea.BeginPosition.Line + 1 to LEndLine - 1 do
      begin
        StringBuilder.Append(LineBreak);
        LEndChar := Length(Items[LLine].Text);
        if ((loTrimTrailingSpaces in Options) and (lsSaving in State)) then
          while ((LEndChar > 0) and (Items[LLine].Text[1 + LEndChar - 1] = BCEDITOR_SPACE_CHAR)) do
            Dec(LEndChar);

        // Debug 2017-05-20
        Assert((0 <= LLine) and (LLine < Items.Count),
          'LLine: ' + IntToStr(LLine) + #13#10
          + 'Count: ' + IntToStr(Items.Count));
        Assert((0 <= LEndChar) and (LEndChar <= Length(Items[LLine].Text)),
          'LEndChar: ' + LEndChar.ToString() + #13#10
          + 'Length: ' + Length(Items[LLine].Text).ToString());

        StringBuilder.Append(Items[LLine].Text, 0, LEndChar);
      end;
      if (LEndLine = AArea.EndPosition.Line) then
        LEndChar := AArea.EndPosition.Char
      else
        LEndChar := Length(Items[LEndLine].Text);
      if ((loTrimTrailingSpaces in Options) and (lsSaving in State) and (LEndChar = Length(Items[LEndLine].Text))) then
        while ((LEndChar > 0) and (Items[LEndLine].Text[1 + LEndChar - 1] = BCEDITOR_SPACE_CHAR)) do
          Dec(LEndChar);
      if ((LEndChar > 0)
        or not (loTrimTrailingSpaces in Options) or not (lsSaving in State) or (LEndChar <> Length(Items[LEndLine].Text))) then
      begin
        StringBuilder.Append(LineBreak);
        StringBuilder.Append(Items[LEndLine].Text, 0, LEndChar);
      end;

      Result := StringBuilder.ToString();

      StringBuilder.Free();
    end;
  end;
end;

function TBCEditorLines.GetTextLength(): Integer;
var
  LLine: Integer;
  LLineBreakLength: Integer;
begin
  Result := 0;
  LLineBreakLength := Length(LineBreak);
  for LLine := 0 to Count - 2 do
  begin
    Inc(Result, Length(Items[LLine].Text));
    Inc(Result, LLineBreakLength);
  end;
  if (Count > 0) then
    Inc(Result, Length(Items[Count - 1].Text))
end;

function TBCEditorLines.GetTextStr: string;
begin
  Include(FState, lsSaving);
  try
    Result := TextIn[LinesArea(BOFPosition, EOFPosition)];
  finally
    Exclude(FState, lsSaving);
  end;
end;

function TBCEditorLines.CharIndexOf(const APosition: TBCEditorLinesPosition): Integer;
var
  LLine: Integer;
  LLineBreakLength: Integer;
begin
  LLineBreakLength := Length(LineBreak);
  Result := 0;
  for LLine := 0 to APosition.Line - 1 do
  begin
    Inc(Result, Length(Items[LLine].Text));
    Inc(Result, LLineBreakLength);
  end;
  Inc(Result, APosition.Char);
end;

procedure TBCEditorLines.Insert(ALine: Integer; const AText: string);
var
  LCaretPosition: TBCEditorLinesPosition;
  LSelArea: TBCEditorLinesArea;
begin
  LCaretPosition := CaretPosition;
  LSelArea := SelArea;

  DoInsert(ALine, AText);

  if (not (lsLoading in State)) then
  begin
    UndoList.Push(utInsert, LCaretPosition, LSelArea,
      LinesArea(BOLPosition[ALine], LinesPosition(Length(AText), ALine)));

    RedoList.Clear();
  end;
end;

procedure TBCEditorLines.InsertIndent(ABeginPosition, AEndPosition: TBCEditorLinesPosition;
  const AIndentText: string);
var
  LArea: TBCEditorLinesArea;
  LCaretPosition: TBCEditorLinesPosition;
  LSelArea: TBCEditorLinesArea;
begin
  LArea.BeginPosition := Min(ABeginPosition, AEndPosition);
  LArea.EndPosition := Max(ABeginPosition, AEndPosition);

  LCaretPosition := CaretPosition;
  LSelArea := SelArea;

  DoInsertIndent(LArea, AIndentText);

  UndoList.Push(utInsertIndent, LCaretPosition, LSelArea,
    LArea, AIndentText);

  RedoList.Clear();
end;

function TBCEditorLines.InsertText(APosition: TBCEditorLinesPosition;
  const AText: string): TBCEditorLinesPosition;
var
  LCaretPosition: TBCEditorLinesPosition;
  LIndex: Integer;
  LPosition: TBCEditorLinesPosition;
  LSelArea: TBCEditorLinesArea;
  LText: string;
begin
  BeginUpdate();
  try
    if (AText = '') then
      Result := APosition
    else
    begin
      LCaretPosition := CaretPosition;
      LSelArea := SelArea;
      if ((APosition.Line < Count) and (APosition.Char <= Length(Items[APosition.Line].Text))) then
      begin
        LPosition := APosition;
        Result := DoInsertText(LPosition, AText);
      end
      else if (APosition.Line < Count) then
      begin
        LPosition := EOLPosition[APosition.Line];
        Result := DoInsertText(LPosition, StringOfChar(BCEDITOR_SPACE_CHAR, APosition.Char - LPosition.Char) + AText);
      end
      else
      begin
        if (Count = 0) then
        begin
          LPosition := BOFPosition;
          LText := '';
        end
        else
        begin
          LPosition := EOLPosition[Count - 1];
          LText := LineBreak;
        end;
        for LIndex := Count to APosition.Line - 1 do
          LText := LText + LineBreak;
        LText := LText + StringOfChar(BCEDITOR_SPACE_CHAR, APosition.Char);
        Result := DoInsertText(LPosition, LText + AText);
      end;

      UndoList.Push(utInsert, LCaretPosition, LSelArea,
        LinesArea(LPosition, Result));
    end;

    CaretPosition := Result;
  finally
    EndUpdate();
    RedoList.Clear();
  end;
end;

procedure TBCEditorLines.InternalClear(const AClearUndo: Boolean);
begin
  if (AClearUndo) then
    ClearUndo();

  Items.Clear();
  LineBreak := BCEDITOR_CARRIAGE_RETURN + BCEDITOR_LINEFEED;
  FCaretPosition := BOFPosition;
  FSelArea := LinesArea(BOFPosition, BOFPosition);
  if (Assigned(OnCleared)) then
    OnCleared(Self);
end;

function TBCEditorLines.IsWordBreakChar(const AChar: Char): Boolean;
begin
  Result := CharInSet(AChar,
    [BCEDITOR_NONE_CHAR .. BCEDITOR_SPACE_CHAR]
    + BCEDITOR_WORD_BREAK_CHARACTERS
    + BCEDITOR_EXTRA_WORD_BREAK_CHARACTERS);
end;

function TBCEditorLines.PositionOf(const ACharIndex: Integer): TBCEditorLinesPosition;
begin
  Result := PositionOf(ACharIndex, BOFPosition);
end;

function TBCEditorLines.PositionOf(const ACharIndex: Integer;
  const ARelativePosition: TBCEditorLinesPosition): TBCEditorLinesPosition;
var
  LLength: Integer;
  LLineBreakLength: Integer;
begin
  Assert((BOFPosition <= ARelativePosition) and (ARelativePosition <= EOFPosition));

  if (Count = 0) then
  begin
    if (ACharIndex <> 0) then
      raise ERangeError.CreateFmt(SCharIndexOutOfBounds, [ACharIndex]);
    Result := BOFPosition;
  end
  else
  begin
    LLength := ACharIndex;

    Result := ARelativePosition;

    if ((0 <= Result.Char + LLength) and (Result.Char + LLength <= Length(Items[Result.Line].Text))) then
      Inc(Result.Char, LLength)
    else if (LLength < 0) then
    begin
      LLineBreakLength := Length(LineBreak);

      Inc(LLength, Result.Char + LLineBreakLength);
      Dec(Result.Line);

      if ((0 <= LLength) and (LLength < LLineBreakLength)) then
        LLength := 0
      else
        while ((Result.Line >= 0) and (LLength < LLineBreakLength)) do
        begin
          Inc(LLength, Length(Items[Result.Line].Text) + LLineBreakLength);
          Dec(Result.Line);
        end;

      if (Result.Line < 0) then
        Result := BOFPosition
      else
      begin
        if (- LLength > Length(Items[Result.Line].Text)) then
          raise ERangeError.CreateFmt(SCharIndexOutOfBounds, [ACharIndex]);

        Result.Char := LLength + Length(Items[Result.Line].Text);
      end;
    end
    else
    begin
      LLineBreakLength := Length(LineBreak);

      Dec(LLength, (Length(Items[Result.Line].Text) - Result.Char) + LLineBreakLength);
      Inc(Result.Line);

      if (LLength < 0) then
        LLength := 0;

      while ((Result.Line < Count) and (LLength >= Length(Items[Result.Line].Text) + LLineBreakLength)) do
      begin
        Dec(LLength, Length(Items[Result.Line].Text) + LLineBreakLength);
        Inc(Result.Line);
      end;

      Result.Char := LLength;

      Result := Min(Result, EOFPosition);
    end;
  end;
end;

procedure TBCEditorLines.Put(ALine: Integer; const AText: string);
begin
  Assert((0 <= ALine) and (ALine < Count));

  ReplaceText(LinesArea(BOLPosition[ALine], EOLPosition[ALine]), AText);
end;

procedure TBCEditorLines.QuickSort(ALeft, ARight: Integer; ACompare: TCompare);
var
  LLeft: Integer;
  LMiddle: Integer;
  LRight: Integer;
begin
  repeat
    LLeft := ALeft;
    LRight := ARight;
    LMiddle := (ALeft + ARight) shr 1;
    repeat
      while ACompare(Self, LLeft, LMiddle) < 0 do
        Inc(LLeft);
      while ACompare(Self, LRight, LMiddle) > 0 do
        Dec(LRight);
      if LLeft <= LRight then
      begin
        if LLeft <> LRight then
          ExchangeItems(LLeft, LRight);
        if LMiddle = LLeft then
          LMiddle := LRight
        else
        if LMiddle = LRight then
          LMiddle := LLeft;
        Inc(LLeft);
        Dec(LRight);
      end;
    until LLeft > LRight;
    if ALeft < LRight then
      QuickSort(ALeft, LRight, ACompare);
    ALeft := LLeft;
  until LLeft >= ARight;
end;

procedure TBCEditorLines.Redo();
begin
  ExecuteUndoRedo(RedoList);
end;

function TBCEditorLines.ReplaceText(const AArea: TBCEditorLinesArea;
  const AText: string): TBCEditorLinesPosition;
var
  LCaretPosition: TBCEditorLinesPosition;
  LSelArea: TBCEditorLinesArea;
  LText: string;
begin
  if (AArea.IsEmpty()) then
    InsertText(AArea.BeginPosition, AText)
  else
  begin
    BeginUpdate();
    try
      LCaretPosition := CaretPosition;
      LSelArea := SelArea;

      LText := TextIn[AArea];

      DoDeleteText(AArea);
      Result := DoInsertText(AArea.BeginPosition, AText);

      // Debug 2017-05-08
      Assert(Result.Char <= Length(Items[Result.Line].Text));

      UndoList.Push(utReplace, LCaretPosition, LSelArea,
        LinesArea(AArea.BeginPosition, Result), LText);

      CaretPosition := Result;
    finally
      EndUpdate();
    end;
  end;
end;

procedure TBCEditorLines.SaveToStream(AStream: TStream; AEncoding: TEncoding);
begin
  inherited;

  if (not (loUndoAfterSave in Options)) then
  begin
    UndoList.Clear();
    RedoList.Clear();
  end;
end;

procedure TBCEditorLines.SetBackground(const ALine: Integer; const AValue: TColor);
begin
  Assert((0 <= ALine) and (ALine < Count));

  Items.List[ALine].Background := AValue;
end;

procedure TBCEditorLines.SetCaretPosition(const AValue: TBCEditorLinesPosition);
begin
  Assert(BOFPosition <= AValue);

  if (AValue <> FCaretPosition) then
  begin
    BeginUpdate();

    FCaretPosition := AValue;

    SelArea := LinesArea(Min(AValue, EOFPosition), Min(AValue, EOFPosition));

    Include(FState, lsCaretMoved);
    EndUpdate();
  end
  else
    SelArea := LinesArea(AValue, AValue);
end;

procedure TBCEditorLines.SetCodeFoldingBeginRange(const ALine: Integer; const AValue: Pointer);
begin
  Assert((0 <= ALine) and (ALine < Count));

  Items.List[ALine].CodeFolding.BeginRange := AValue;
end;

procedure TBCEditorLines.SetCodeFoldingEndRange(const ALine: Integer; const AValue: Pointer);
begin
  Assert((0 <= ALine) and (ALine < Count));

  Items.List[ALine].CodeFolding.EndRange := AValue;
end;

procedure TBCEditorLines.SetCodeFoldingTreeLine(const ALine: Integer; const AValue: Boolean);
begin
  Assert((0 <= ALine) and (ALine < Count));

  Items.List[ALine].CodeFolding.TreeLine := AValue;
end;

procedure TBCEditorLines.SetFirstRow(const ALine: Integer; const AValue: Integer);
begin
  Assert((0 <= ALine) and (ALine < Count));

  Items.List[ALine].FirstRow := AValue;
end;

procedure TBCEditorLines.SetForeground(const ALine: Integer; const AValue: TColor);
begin
  Assert((0 <= ALine) and (ALine < Count));

  Items.List[ALine].Foreground := AValue;
end;

procedure TBCEditorLines.SetModified(const AValue: Boolean);
var
  LLine: Integer;
begin
  if (FModified <> AValue) then
  begin
    FModified := AValue;

    if (not FModified) then
    begin
      UndoList.GroupBreak();

      BeginUpdate();
      for LLine := 0 to Count - 1 do
        if (Items[LLine].State = lsModified) then
          Items.List[LLine].State := lsSaved;
      EndUpdate();
      Editor.Invalidate();
    end;
  end;
end;

procedure TBCEditorLines.SetRange(const ALine: Integer; const AValue: Pointer);
begin
  Assert((0 <= ALine) and (ALine < Count));

  Items.List[ALine].Range := AValue;
end;

procedure TBCEditorLines.SetSelArea(AValue: TBCEditorLinesArea);
begin
  if (AValue <> FSelArea) then
  begin
    BeginUpdate();

    FSelArea.BeginPosition := AValue.BeginPosition;
    if (FSelArea.BeginPosition.Line < Count) then
      FSelArea.BeginPosition.Char := Min(FSelArea.BeginPosition.Char, Length(Items[FSelArea.BeginPosition.Line].Text))
    else
      FSelArea.BeginPosition := EOFPosition;

    FSelArea.EndPosition := AValue.EndPosition;
    if (FSelArea.EndPosition.Line < Count) then
      FSelArea.EndPosition.Char := Min(FSelArea.EndPosition.Char, Length(Items[FSelArea.EndPosition.Line].Text))
    else
      FSelArea.EndPosition := EOFPosition;

    Include(FState, lsSelChanged);
    EndUpdate();
  end;
end;

procedure TBCEditorLines.SetTextStr(const AValue: string);
var
  LEndPosition: TBCEditorLinesPosition;
  LLine: Integer;
  LOldCaretPosition: TBCEditorLinesPosition;
  LOldSelArea: TBCEditorLinesArea;
begin
  LOldCaretPosition := CaretPosition;
  LOldSelArea := SelArea;

  Include(FState, lsLoading);

  BeginUpdate();

  if (loUndoAfterLoad in Options) then
    DeleteText(LinesArea(BOFPosition, EOFPosition));

  InternalClear(not (loUndoAfterLoad in Options));

  LEndPosition := InsertText(BOFPosition, AValue);
  for LLine := 0 to Count - 1 do
    Items.List[LLine].State := lsLoaded;

  if (loUndoAfterLoad in Options) then
  begin
    UndoList.Push(utInsert, BOFPosition, InvalidLinesArea,
      LinesArea(BOFPosition, LEndPosition));

    RedoList.Clear();
  end;

  CaretPosition := BOFPosition;

  EndUpdate();

  Exclude(FState, lsLoading);
end;

procedure TBCEditorLines.SetUpdateState(AUpdating: Boolean);
begin
  if (AUpdating) then
  begin
    if (not (csReading in Editor.ComponentState) and Assigned(OnBeforeUpdate)) then
      OnBeforeUpdate(Self);

    UndoList.BeginUpdate();
    FState := FState - [lsCaretMoved, lsSelChanged, lsTextChanged];
    FOldUndoListCount := UndoList.Count;
    FOldCaretPosition := CaretPosition;
    FOldSelArea := SelArea;
  end
  else
  begin
    if (not (lsRedo in State) and ((lsCaretMoved in State) or (lsSelChanged in State)) and not UndoList.Updated) then
    begin
      if (not (lsUndo in State)) then
      begin
        if ((UndoList.Count = FOldUndoListCount)
          and (CaretPosition <> FOldCaretPosition)
            or (SelArea <> FOldSelArea)) then
          UndoList.Push(utSelection, FOldCaretPosition, FOldSelArea,
            InvalidLinesArea);
        RedoList.Clear();
      end;
    end;

    UndoList.EndUpdate();

    if (Assigned(OnCaretMoved) and (lsCaretMoved in FState)) then
      OnCaretMoved(Self);
    if (Assigned(OnSelChange) and (lsSelChanged in FState)) then
      OnSelChange(Self);
    if (Assigned(OnAfterUpdate)) then
      OnAfterUpdate(Self);

    FState := FState - [lsCaretMoved, lsSelChanged, lsTextChanged];
  end;
end;

procedure TBCEditorLines.Sort(const ABeginLine, AEndLine: Integer);
begin
  CustomSort(ABeginLine, AEndLine, CompareLines);
end;

procedure TBCEditorLines.Undo();
begin
  ExecuteUndoRedo(UndoList);
end;

procedure TBCEditorLines.UndoGroupBreak();
begin
  if ((loUndoGrouped in Options) and CanUndo) then
    UndoList.GroupBreak();
end;

function TBCEditorLines.ValidPosition(const APosition: TBCEditorLinesPosition): Boolean;
begin
  Result := (0 <= APosition.Line) and (APosition.Line < Count)
    and (0 <= APosition.Char) and (APosition.Char < Length(Items[APosition.Line].Text));
end;

end.

