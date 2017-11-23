# active-object-delphi
Active Object Concurrency Design Pattern Implemented in Delphi. A Proxy can wrap a Servant object and run requests to the Servant in a thread. The Servant object does not know of the concurrency system and the Proxy can present a similar interface as the Servant. 

Source code for blog posts on the Active Object Pattern
https://schellingerhout.github.io/tags/#active-object

```
procedure TProxy.put(const msg: TMessage);
var
  LMsg: TMessage;
begin
  LMsg := msg;
  FScheduler.Equeue(
    TMethodRequest.Create(
      // Call
      procedure
      begin
        FServant.put_i(LMsg);
      end,

      // Optional Guard
      function : boolean
      begin
        result := not FServant.full_i;
      end
    )
  );
end;
```

I also provided a Future interface to enqueue methods that should return values.

```
function TProxy.get: IFuture<TMessage>;
var
  LActiveFuture: TFuture<TMessage>;
begin
  LActiveFuture := TFutureValue<TMessage>.Create;
  result := LActiveFuture;

  FScheduler.Enqueue(
    TMethodRequest.Create(
      // Call
      procedure
      begin
        LActiveFuture.SetValue(FServant.get_i); // closure over the future and servant
      end,

      // Optional Guard
      function : boolean
      begin
        result := not FServant.empty_i;
      end
    )
  );
end;
```


