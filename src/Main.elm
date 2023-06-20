module Main exposing (main)

import Angle exposing (Angle)
import AngularSpeed exposing (AngularSpeed)
import Browser
import Browser.Events exposing (onAnimationFrameDelta, onResize)
import Camera3d
import Color
import Duration exposing (Duration)
import Element exposing (Element, text)
import Element.Background as BG
import Element.Border as Border
import Element.Input as Input
import Frame3d
import Html exposing (Html)
import Html.Attributes
import Html.Events
import Html.Events.Extra.Pointer as Pointer exposing (onDown, onUp)
import Json.Decode as Decode exposing (Decoder)
import Length exposing (Length)
import Pixels exposing (Pixels)
import Point3d
import Quantity exposing (Quantity)
import Scene3d
import Scene3d.Material as Material
import Sphere3d
import Task
import Viewpoint3d
import WebGL.Texture


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


type alias Flags =
    ( Int, Int )


type alias Model =
    { time : Duration
    , sunTexture : Texture
    , mercuryTexture : Texture
    , venusTexture : Texture
    , earthTexture : Texture
    , moonTexture : Texture
    , marsTexture : Texture
    , distance : Length
    , viewHeight : Int
    , viewWidth : Int
    , userRotating : Bool
    , azimuthView : Angle
    , elevationView : Angle
    }


type Msg
    = OnFrameDelta Float
    | OnSunTextureLoad Planet (Result WebGL.Texture.Error Texture)
    | DistanceChanged Float
    | OnWindowResize Int Int
    | OnMove ( Quantity Float Pixels, Quantity Float Pixels )
    | OnUp
    | OnDown


type alias MyPointerEvent =
    { pointerEvent : Pointer.Event
    , movement : ( Float, Float )
    }


myEventDecoder : Decoder MyPointerEvent
myEventDecoder =
    let
        movementDecoder =
            Decode.map2 Tuple.pair
                (Decode.field "movementX" Decode.float)
                (Decode.field "movementY" Decode.float)
    in
    Decode.map2 MyPointerEvent
        Pointer.eventDecoder
        movementDecoder


myOnMove : (MyPointerEvent -> Msg) -> Html.Attribute Msg
myOnMove tag =
    let
        decoder =
            myEventDecoder
                |> Decode.map tag
                |> Decode.map options

        options message =
            { message = message
            , stopPropagation = False
            , preventDefault = True
            }
    in
    Html.Events.custom "pointermove" decoder


relativePos : MyPointerEvent -> ( Quantity Float Pixels, Quantity Float Pixels )
relativePos event =
    event.movement
        |> Tuple.mapBoth Pixels.float Pixels.float


type Planet
    = Sun
    | Mercury
    | Venus
    | Earth
    | Moon
    | Mars


init : Flags -> ( Model, Cmd Msg )
init ( h, w ) =
    ( { time = Quantity.zero
      , sunTexture = Material.constant Color.yellow
      , mercuryTexture = Material.constant Color.grey
      , venusTexture = Material.constant Color.red
      , earthTexture = Material.constant Color.blue
      , moonTexture = Material.constant Color.white
      , marsTexture = Material.constant Color.red
      , distance = Length.meters 20
      , viewHeight = h
      , viewWidth = w
      , userRotating = False
      , azimuthView = Quantity.zero
      , elevationView = Viewpoint3d.isometricElevation
      }
    , Cmd.batch
        [ Material.load "/images/sun.jpeg"
            |> Task.attempt (OnSunTextureLoad Sun)
        , Material.load "/images/mercury.jpeg"
            |> Task.attempt (OnSunTextureLoad Mercury)
        , Material.load "/images/venus.jpeg"
            |> Task.attempt (OnSunTextureLoad Venus)
        , Material.load "/images/earth.jpeg"
            |> Task.attempt (OnSunTextureLoad Earth)
        , Material.load "/images/moon.jpeg"
            |> Task.attempt (OnSunTextureLoad Moon)
        , Material.load "/images/mars.jpeg"
            |> Task.attempt (OnSunTextureLoad Mars)
        ]
    )


view : Model -> Html Msg
view model =
    Element.layout [] <|
        Element.column []
            [ [ scene model ]
                |> Html.div
                    [ myOnMove (relativePos >> OnMove)
                    , onUp <| always OnUp
                    , onDown <| always OnDown
                    , Html.Attributes.style "touch-action" "none"
                    , Html.Attributes.id "canvas"
                    ]
                |> Element.html
            , contorls model
            ]


contorls : Model -> Element Msg
contorls model =
    Input.slider
        [ Element.behindContent
            (Element.el
                [ Element.width Element.fill
                , Element.height (Element.px 2)
                , Element.centerY
                , Color.toRgba Color.grey
                    |> Element.fromRgb
                    |> BG.color
                , Border.rounded 2
                ]
                Element.none
            )
        ]
        { onChange = DistanceChanged
        , label =
            Input.labelAbove []
                (text "Расстояние")

        -- (Element.paragraph [] [ text model.dbg ])
        , min = 5
        , max = 30
        , step = Nothing
        , value = model.distance |> Length.inMeters
        , thumb =
            Input.defaultThumb
        }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        newModel =
            case msg of
                DistanceChanged dist ->
                    { model | distance = Length.meters dist }

                OnFrameDelta delta ->
                    { model | time = Quantity.plus model.time (Duration.milliseconds delta) }

                OnWindowResize w h ->
                    { model | viewWidth = w, viewHeight = h }

                OnUp ->
                    { model | userRotating = False }

                OnDown ->
                    { model | userRotating = True }

                OnMove ( dx, dy ) ->
                    if model.userRotating then
                        let
                            rotationRate =
                                Angle.degrees 1 |> Quantity.per Pixels.pixel
                        in
                        { model
                            | azimuthView =
                                dx
                                    |> Quantity.negate
                                    |> Quantity.at rotationRate
                                    |> Quantity.plus model.azimuthView
                            , elevationView =
                                dy
                                    |> Quantity.at rotationRate
                                    |> Quantity.plus model.elevationView
                        }

                    else
                        model

                OnSunTextureLoad planet (Ok texture) ->
                    case planet of
                        Sun ->
                            { model | sunTexture = texture }

                        Mercury ->
                            { model | mercuryTexture = texture }

                        Venus ->
                            { model | venusTexture = texture }

                        Earth ->
                            { model | earthTexture = texture }

                        Moon ->
                            { model | moonTexture = texture }

                        Mars ->
                            { model | marsTexture = texture }

                OnSunTextureLoad _ (Err _) ->
                    model
    in
    ( newModel, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch <|
        [ onAnimationFrameDelta OnFrameDelta
        , onResize OnWindowResize
        ]



-- SHAPES


type WorldCoordinates
    = WorldCoordinates


type PlanetCoordinates
    = PlanetCoordinates


type SatelliteCoordinates
    = SatelliteCoordinates


type alias PlanetSphere =
    Sphere3d.Sphere3d Length.Meters PlanetCoordinates


type alias SatelliteSphere =
    Sphere3d.Sphere3d Length.Meters SatelliteCoordinates


type alias PlanetFrame =
    Frame3d.Frame3d Length.Meters WorldCoordinates { defines : PlanetCoordinates }


type alias SatelliteFrame =
    Frame3d.Frame3d Length.Meters PlanetCoordinates { defines : SatelliteCoordinates }


type alias Entity =
    Scene3d.Entity WorldCoordinates


type alias Texture =
    Material.Texture Color.Color


renderPlanet : Texture -> PlanetSphere -> Duration -> AngularSpeed -> PlanetFrame -> Entity
renderPlanet txt sphere duration speed frame =
    let
        angle =
            speed |> Quantity.for duration

        axis =
            Frame3d.zAxis frame
    in
    Scene3d.sphere (Material.texturedColor txt) sphere
        |> Scene3d.placeIn frame
        |> Scene3d.rotateAround axis angle


renderSatellite : Texture -> SatelliteSphere -> Duration -> AngularSpeed -> PlanetFrame -> SatelliteFrame -> Entity
renderSatellite txt sphere duration speed planet frame =
    let
        angle =
            speed |> Quantity.for duration

        axis =
            Frame3d.zAxis frame
    in
    Scene3d.sphere (Material.texturedColor txt) sphere
        |> Scene3d.placeIn frame
        |> Scene3d.rotateAround axis angle
        |> Scene3d.placeIn planet


planetFrame : Float -> PlanetFrame
planetFrame position =
    Frame3d.atPoint <| Point3d.meters (position + 3) 0 0


satelliteFrame : Float -> SatelliteFrame
satelliteFrame position =
    Frame3d.atPoint <| Point3d.centimeters (50 * position) 0 0


earthSize : Length
earthSize =
    Length.meters 0.2


planetSphere : Float -> PlanetSphere
planetSphere earthScale =
    Sphere3d.atOrigin (Quantity.multiplyBy earthScale earthSize)


satelliteSphere : Float -> SatelliteSphere
satelliteSphere scale =
    Sphere3d.atOrigin (Quantity.multiplyBy scale earthSize)


sunSphere : PlanetSphere
sunSphere =
    planetSphere 10


sunRotateVelocity : AngularSpeed.AngularSpeed
sunRotateVelocity =
    rotateVelocity 25.4


earthSphere : PlanetSphere
earthSphere =
    planetSphere 1


earthFrame : PlanetFrame
earthFrame =
    planetFrame 3


earthOrbitVelocity : AngularSpeed.AngularSpeed
earthOrbitVelocity =
    AngularSpeed.turnsPerMinute 0.3


earthRotateVelocity : AngularSpeed.AngularSpeed
earthRotateVelocity =
    earthOrbitVelocity |> Quantity.multiplyBy 365


rotateVelocity : Float -> AngularSpeed.AngularSpeed
rotateVelocity days =
    earthRotateVelocity |> Quantity.divideBy days


orbitVelocity : Float -> AngularSpeed.AngularSpeed
orbitVelocity days =
    earthOrbitVelocity |> Quantity.multiplyBy (365 / days)


mercurySphere : PlanetSphere
mercurySphere =
    planetSphere 0.38


mercuryFrame : PlanetFrame
mercuryFrame =
    planetFrame 1


mercuryOrbitVelocity : AngularSpeed.AngularSpeed
mercuryOrbitVelocity =
    orbitVelocity 88


mercuryRotateVelocity : AngularSpeed.AngularSpeed
mercuryRotateVelocity =
    rotateVelocity 58.6


venusSphere : PlanetSphere
venusSphere =
    planetSphere 0.95


venusFrame : PlanetFrame
venusFrame =
    planetFrame 2


venusOrbitVelocity : AngularSpeed.AngularSpeed
venusOrbitVelocity =
    orbitVelocity 224.7


venusRotateVelocity : AngularSpeed.AngularSpeed
venusRotateVelocity =
    rotateVelocity 243


moonSphere : SatelliteSphere
moonSphere =
    satelliteSphere 0.27


moonFrame : SatelliteFrame
moonFrame =
    satelliteFrame 1


moonOrbitVelocity : AngularSpeed.AngularSpeed
moonOrbitVelocity =
    orbitVelocity 27.3


moonRotateVelocity : AngularSpeed.AngularSpeed
moonRotateVelocity =
    rotateVelocity 27.3


marsSphere : PlanetSphere
marsSphere =
    planetSphere 0.5


marsFrame : PlanetFrame
marsFrame =
    planetFrame 4


marsOrbitVelocity : AngularSpeed.AngularSpeed
marsOrbitVelocity =
    orbitVelocity 687


marsRotateVelocity : AngularSpeed.AngularSpeed
marsRotateVelocity =
    rotateVelocity 1


orbit : Duration.Duration -> AngularSpeed -> PlanetFrame -> PlanetFrame -> PlanetFrame
orbit duration speed center frame =
    let
        angle =
            speed |> Quantity.for duration

        axis =
            Frame3d.zAxis center
    in
    frame
        |> Frame3d.rotateAround axis angle


satelliteOrbit : Duration.Duration -> AngularSpeed -> PlanetFrame -> SatelliteFrame -> SatelliteFrame
satelliteOrbit duration speed around frame =
    let
        angle =
            speed |> Quantity.for duration

        axis =
            Frame3d.zAxis around
    in
    frame
        |> Frame3d.placeIn around
        |> Frame3d.rotateAround axis angle
        |> Frame3d.relativeTo around


scene : Model -> Html msg
scene model =
    let
        sun =
            Frame3d.atOrigin

        mercury =
            mercuryFrame
                |> orbit model.time mercuryOrbitVelocity sun

        venus =
            venusFrame
                |> orbit model.time venusOrbitVelocity sun

        earth =
            earthFrame
                |> orbit model.time earthOrbitVelocity sun

        moon =
            moonFrame
                |> satelliteOrbit model.time moonOrbitVelocity earth

        mars =
            marsFrame
                |> orbit model.time marsOrbitVelocity sun
    in
    Scene3d.unlit
        { entities =
            [ sun
                |> renderPlanet model.sunTexture sunSphere model.time sunRotateVelocity
            , mercury
                |> renderPlanet model.mercuryTexture mercurySphere model.time mercuryRotateVelocity
            , venus
                |> renderPlanet model.venusTexture venusSphere model.time venusRotateVelocity
            , earth
                |> renderPlanet model.earthTexture earthSphere model.time earthRotateVelocity
            , moon
                |> renderSatellite model.moonTexture moonSphere model.time moonRotateVelocity earth
            , mars
                |> renderPlanet model.marsTexture marsSphere model.time marsRotateVelocity
            ]
        , camera =
            Camera3d.perspective
                { viewpoint =
                    Viewpoint3d.orbitZ
                        { focalPoint = Point3d.origin
                        , distance = model.distance
                        , azimuth = model.azimuthView
                        , elevation = model.elevationView
                        }
                , verticalFieldOfView = Angle.degrees 45
                }
        , clipDepth = Length.meters 1
        , background = Scene3d.backgroundColor Color.black
        , dimensions = ( Pixels.pixels model.viewWidth, Pixels.pixels <| model.viewHeight - 50 )
        }
