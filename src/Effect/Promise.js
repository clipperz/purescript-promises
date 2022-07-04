function thenImpl (promise, onFulfilled, onRejected) {
  return promise.then(onFulfilled, onRejected);
}

function catchImpl (promise, f) {
  return promise.catch(f);
}

function resolveImpl (a) {
  return Promise.resolve(a);
}

function rejectImpl (a) {
  return Promise.reject(a);
}

function promiseToEffectImpl (promise, onFulfilled, onRejected) {
  return function () {
    return promise.then(function (a) {
      return onFulfilled(a)();
    }, function (err) {
      return onRejected(err)();
    });
  };
}

function allImpl (arr) {
  return Promise.all(arr);
}

function raceImpl (arr) {
  return Promise.race(arr);
}

function liftEffectImpl (eff) {
  return new Promise(function (onSucc, onErr) {
    try {
      result = eff();
    } catch (err) {
      return onErr(err);
    }
    return onSucc(result);
  });
}

function promiseImpl (callback) {
  return new Promise(function(resolve, reject) {
    callback(function (a) {
      return function () {
        resolve(a);
      };
    }, function (err) {
      return function () {
        reject(err);
      };
    })();
  });
}

function delayImpl (a, ms) {
  return new Promise(function (resolve, reject) {
    setTimeout(resolve, ms, a);
  });
}

export {allImpl, catchImpl, delayImpl, liftEffectImpl, promiseImpl, promiseToEffectImpl, raceImpl,  rejectImpl, resolveImpl, thenImpl}