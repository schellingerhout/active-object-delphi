unit FutureValue;

interface
uses
  system.syncobjs;

type

  IFutureValue<T> = interface(IInterface)
    function GetValue: T;
    property Value: T read GetValue;
  end;

  TFutureValue<T> = class(TInterfacedObject, IFutureValue<T>)
  private
    FResultSet: boolean;
    FResult: T;
    FValueReadyEvent: TLightWeightEvent;
    // consider balance between TEvent and TLightweight event
    function GetValue: T;
    function Wait: boolean;
    function GetValueReadyEvent: TLightWeightEvent;

  protected


    property ValueReadyEvent: TLightWeightEvent read GetValueReadyEvent;
  public
    destructor Destroy; override;
    procedure SetValue(AResult: T); // done by methodrequest wrapping a future
    property Value: T read GetValue;
  end;


implementation

{ TActiveFuture<T> }

destructor TFutureValue<T>.Destroy;
begin

  FValueReadyEvent.Free;
  inherited;

end;

function TFutureValue<T>.GetValue: T;
begin
  Wait;
  result := FResult;
end;

function TFutureValue<T>.GetValueReadyEvent: TLightWeightEvent;
var
  LEvent: TLightWeightEvent;
begin
  if FValueReadyEvent = nil then
  begin
    LEvent := TLightWeightEvent.Create;
    if TInterlocked.CompareExchange<TLightWeightEvent>(FValueReadyEvent, LEvent,
      nil) <> nil then
      LEvent.Free;

    if FResultSet then
      FValueReadyEvent.SetEvent;
  end;
  result := FValueReadyEvent;
end;


procedure TFutureValue<T>.SetValue(AResult: T);
begin
  //raise exception if set twice!
  FResult := AResult; //no -one can read until we set the flag anyway.
  FResultSet := true; //don't think interlock exchange is needed
  GetValueReadyEvent.SetEvent;
end;

function TFutureValue<T>.Wait: boolean;
begin
  if not FResultSet then   //set after value is set
  begin
    result := ValueReadyEvent.WaitFor(INFINITE) <> TWaitResult.wrTimeout;
  end;

end;

end.
