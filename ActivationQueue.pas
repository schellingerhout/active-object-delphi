unit ActivationQueue;

interface

uses
  system.classes, system.syncobjs, system.generics.collections, system.sysutils;

Type

  IFutureValue<T> = interface
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
    function Wait(TimeOut: Cardinal): boolean;
    function GetValueReadyEvent: TLightWeightEvent;

  protected


    property ValueReadyEvent: TLightWeightEvent read GetValueReadyEvent;
  public
    destructor Destroy; override;
    procedure SetValue(AResult: T); // done by methodrequest wrapping a future
    property Value: T read GetValue;
  end;

  TMethodRequest = class
  private
    FCall: TProc;
    FGuard: TFunc<boolean>;
    FGuardless: boolean;
  public
    constructor Create(const ACall: TProc; const AGuard: TFunc<boolean> = nil);

    function guard: boolean; virtual; // returns true as default
    procedure call; virtual;
  end;

  TActivationScheduler = class(TThread)
  private
    FDataReady: TEvent;
    FActivationQueue: TQueue<TMethodRequest>;
  protected
    // Dispatch the Method Requests on their Servant
    // in the Scheduler’s thread.

    procedure Execute; override;
  public

    constructor Create;
    destructor Destroy; override;

    // Insert the Method Request into
    // the Activation_Queue. This method
    // runs in the thread of its client, i.e.,
    // in the Proxy’s thread.

    procedure enqueue(AMethodRequest: TMethodRequest);

  end;

implementation

{ TActivationScheduler }

constructor TActivationScheduler.Create;
begin
  inherited Create(False);
  FreeOnTerminate := true;

  FDataReady := TEvent.Create();
  FActivationQueue := TQueue<TMethodRequest>.Create;
end;

destructor TActivationScheduler.Destroy;
begin
  FDataReady.SetEvent;
  FDataReady.Free;
  FActivationQueue.Free;

  inherited;
end;

procedure TActivationScheduler.enqueue(AMethodRequest: TMethodRequest);
begin
  system.TMonitor.Enter(FActivationQueue);
  try
    FActivationQueue.enqueue(AMethodRequest);
  finally
    system.TMonitor.Exit(FActivationQueue);
  end;

  FDataReady.SetEvent;
end;

procedure TActivationScheduler.Execute;
var
  LMethodRequest: TMethodRequest;
  i, LCount: integer;
begin
  inherited;
  while not terminated do
  begin
    FDataReady.WaitFor();

    system.TMonitor.Enter(FActivationQueue);
    try
      LCount := FActivationQueue.Count;
    finally
      system.TMonitor.Exit(FActivationQueue);
    end;

    for i := 1 to LCount do
    begin
      system.TMonitor.Enter(FActivationQueue);
      try
        LMethodRequest := FActivationQueue.Peek;
        if LMethodRequest.guard then
        begin
          LMethodRequest := FActivationQueue.Dequeue;
          // if its not the same object we have a serious problem in our design
        end
        else
        begin
          // If method_request fail guards continually or for reasons that are never resolved
          // this thread will loop around and around and never finish
          LMethodRequest := nil;
        end;

      finally
        system.TMonitor.Exit(FActivationQueue);
      end;

      if LMethodRequest <> nil then
        LMethodRequest.call;

    end;

    system.TMonitor.Enter(FActivationQueue);
    try
      if FActivationQueue.Count = 0 then
        FDataReady.ResetEvent;

    finally
      system.TMonitor.Exit(FActivationQueue);
    end;

  end;

end;

{ TMethodRequest }

procedure TMethodRequest.call;
begin
  FCall;
end;

constructor TMethodRequest.Create(const ACall: TProc;
  const AGuard: TFunc<boolean> = nil);
begin
  inherited Create;
  FCall := ACall;
  FGuard := AGuard;
  FGuardless := not Assigned(AGuard);

end;

function TMethodRequest.guard: boolean;
begin
  if FGuardless then
    result := true
  else
    result := FGuard;
end;

{ TActiveFuture<T> }

destructor TFutureValue<T>.Destroy;
begin

  FValueReadyEvent.Free;
  inherited;

end;

function TFutureValue<T>.GetValue: T;
begin
  Wait(INFINITE);
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
  FResultSet := true;
  GetValueReadyEvent.SetEvent;
end;

function TFutureValue<T>.Wait(TimeOut: Cardinal): boolean;
begin
  if not FResultSet then   //set after value is set
  begin
    result := ValueReadyEvent.WaitFor(TimeOut) <> TWaitResult.wrTimeout;
  end;

end;

end.
