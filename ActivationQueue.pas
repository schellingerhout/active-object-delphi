//  
// Copyright (c) Jasper Schellingerhout. All rights reserved.  
// Licensed under the MIT License. See LICENSE file in the project root for full license information.  
//
// I kindly request that you notify me if you use this in your software projects.
// Project located at: https://github.com/schellingerhout/active-object-delphi

unit ActivationQueue;

interface

uses
  system.classes, system.syncobjs, system.generics.collections, system.sysutils;

Type

  TMethodRequest = class(TObject)
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
    FGuardedMethodRequests: TList<TMethodRequest>;
    FActivationQueue: TQueue<TMethodRequest>;
    procedure CallPreviouslyGuarded;
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
  FGuardedMethodRequests := TList<TMethodRequest>.Create;
end;

destructor TActivationScheduler.Destroy;
begin
  FDataReady.SetEvent;
  FDataReady.Free;
  FActivationQueue.Free;
  FGuardedMethodRequests.Free;

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

procedure TActivationScheduler.CallPreviouslyGuarded;
var
  i: integer;
  LMethodRequest: TMethodRequest;
begin
  // deal with previously guarded requests
  for i := 0 to FGuardedMethodRequests.Count - 1 do
  begin
    LMethodRequest := FGuardedMethodRequests[i];
    if LMethodRequest.guard then
    begin
      LMethodRequest.call;
      LMethodRequest.Free;
      FGuardedMethodRequests[i] := nil;
    end;
    if Terminated then
      exit;
  end;
  FGuardedMethodRequests.Pack;
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

    CallPreviouslyGuarded;

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
        LMethodRequest := FActivationQueue.Dequeue;
      finally
        system.TMonitor.Exit(FActivationQueue);
      end;

      if not LMethodRequest.guard then
      begin
        FGuardedMethodRequests.Add(LMethodRequest);
        LMethodRequest := nil;
      end;

      if LMethodRequest <> nil then
      begin
        LMethodRequest.call;
        // we need to check if the call lifted any guards
        CallPreviouslyGuarded;
      end;
      if Terminated then
        exit;
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

end.
