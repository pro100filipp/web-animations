const { Elm } = require("./Main.elm");

const appContainer = document.createElement("div");
document.body.appendChild(appContainer);

interface HTMLElement {
  realAddEventListener(
    type: string,
    listener: EventListenerOrEventListenerObject,
    options?: boolean | AddEventListenerOptions
  ): void;
}

interface RealPointerEvent
  extends Omit<PointerEvent, "movementX" | "movementY"> {
  movementX?: number;
  movementY?: number;
}

class TouchMovement {
  cachedX: number = 0;
  cachedY: number = 0;
  deltaX: number = 0;
  deltaY: number = 0;

  touchMovement = (el: HTMLElement): void => {
    el.ontouchstart = (e: TouchEvent) => {
      this.cachedX = e.touches[0].clientX;
      this.cachedY = e.touches[0].clientY;
    };
    el.ontouchmove = (e: TouchEvent) => {
      this.deltaX = e.changedTouches[0].clientX - this.cachedX;
      this.deltaY = e.changedTouches[0].clientY - this.cachedY;
      this.cachedX = e.changedTouches[0].clientX;
      this.cachedY = e.changedTouches[0].clientY;
    };
  };
}

HTMLElement.prototype.realAddEventListener =
  HTMLElement.prototype.addEventListener;

HTMLElement.prototype.addEventListener = function (
  type: string,
  listener: EventListenerOrEventListenerObject,
  options?: boolean | AddEventListenerOptions
) {
  if (type === "pointermove") {
    const touchTracker = new TouchMovement();
    touchTracker.touchMovement(this);
    const addMovementListener = (e: RealPointerEvent): void => {
      if (e.movementX === undefined) {
        e.movementX = touchTracker.deltaX;
        e.movementY = touchTracker.deltaY;
      }
      if (typeof listener === "function") listener(e);
      else listener.handleEvent(e);
    };
    this.realAddEventListener(
      type,
      addMovementListener as EventListener,
      options
    );
  } else this.realAddEventListener(type, listener, options);
};

const app = Elm.Main.init({
  node: appContainer,
  flags: [window.innerHeight, window.innerWidth],
});
