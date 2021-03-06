(* The Computer Language Benchmarks Game
   https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
   - Based on "Go #4" by Martin Koistinen
   - Contributed by Akira1364
*)

program mandelbrot_new;

uses CMem, {$ifdef Unix}CThreads,{$ENDIF} SysUtils, Math, MTProcs;

{$ifdef Unix}
  var CStdOut: Pointer; external 'c' name 'stdout';
  
  procedure PrintF(const Format: PChar); cdecl; varargs; external 'c' name 'printf';
  
  function FWrite(const DataStart: Pointer;
                  ElementSize: PtrUInt;
                  ElementCount: PtrUInt;
                  Stream: Pointer
                 ): PtrUInt; cdecl; external 'c' name 'fwrite';
{$endif}               

const
  Limit = 4.0;
  Size: PtrInt = 200;

type
  TDoublePair = array[0..1] of Double;
  PDoublePair = ^TDoublePair;
  
  TData = record
    Rows: PByte;
    InitialIR: PDoublePair;
  end;
  PData = ^TData;

var
  BytesPerRow: PtrInt;
  Inv: Double;

  procedure RenderRows(Index: PtrInt;
                       UserData: Pointer;
                       Item: TMultiThreadProcItem);
  var
    Res, B: Byte;
    XByte, I, J, X: PtrInt;
    ZRA, ZRB, ZIA, ZIB, TRA, TRB, TIA, TIB, CRA, CRB, CI: Double;
  begin
    with TData(UserData^) do begin
      CI := InitialIR[Index][0];
      for XByte := Pred(BytesPerRow) downto 0 do begin
        Res := 0;
        I := 0;
        repeat
          X := XByte shl 3;
          CRA := InitialIR[X + I][1];
          CRB := InitialIR[X + I + 1][1];
          ZRA := CRA;
          ZIA := CI;
          ZRB := CRB;
          ZIB := CI;
          B := 0;
          for J := 49 downto 0 do begin
            TRA := ZRA * ZRA;
            TIA := ZIA * ZIA;
            if TRA + TIA > Limit then begin
              B := B or 2;
              if B = 3 then Break;
            end;
            TRB := ZRB * ZRB;
            TIB := ZIB * ZIB;
            if TRB + TIB > Limit then begin
              B := B or 1;
              if B = 3 then Break;
            end;
            ZIA := 2 * ZRA * ZIA + CI;
            ZRA := TRA - TIA + CRA;
            ZIB := 2 * ZRB * ZIB + CI;
            ZRB := TRB - TIB + CRB;
          end;
          Res := (Res shl 2) or B;
          I += 2;
        until I = 8;
        Rows[(Index * BytesPerRow) + XByte] := not Res;
      end;
    end;
  end;

  procedure MakeLookupTables(Index: PtrInt;
                             UserData: Pointer;
                             Item: TMultiThreadProcItem);
  var InvScaled: Double;
  begin
    InvScaled := Inv * Double(Index);
    with TData(UserData^) do begin
      InitialIR[Index][0] := InvScaled - 1.0;
      InitialIR[Index][1] := InvScaled - 1.5;
    end;
  end;

var
  Data: TData;
  {$ifndef Unix}
    IO: PText;
  {$endif}

begin
  SetExceptionMask([exInvalidOp, exOverflow, exPrecision]);
  if ParamCount > 0 then Val(ParamStr(1), Size);
  BytesPerRow := Size shr 3;
  with Data do begin
    GetMem(InitialIR, SizeOf(TDoublePair) * Size);
    GetMem(Rows, BytesPerRow * Size);
  end;
  Inv := 2.0 / Double(Size);
  with ProcThreadPool do begin
    DoParallel(@MakeLookupTables, 0, Pred(Size), @Data);
    DoParallel(@RenderRows, 0, Pred(Size), @Data);
  end;
  {$ifdef Unix}
    PrintF('P4'#10'%d %d'#10, Size, Size);
    FWrite(@Data.Rows[0], BytesPerRow, Size, CStdOut);
  {$else}
    IO := @Output;
    Write(IO^, 'P4', #10, Size, ' ', Size, #10);
    Flush(IO^);
    FileWrite(StdOutPutHandle, Data.Rows[0], BytesPerRow * Size);
  {$endif}
  with Data do begin
    FreeMem(InitialIR);
    FreeMem(Rows);
  end;
end.
