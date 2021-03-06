module Internal.Checkbox.Implementation exposing
    ( checked
    , disabled
    , nativeControl
    , Property
    , react
    , view
    )

import Html.Attributes as Html
import Html exposing (Html, text)
import Json.Decode as Json exposing (Decoder)
import Json.Encode
import Internal.Checkbox.Model exposing (Model, defaultModel, Msg(..), Animation(..), State(..))
import Internal.Component as Component exposing (Indexed, Index)
import Internal.GlobalEvents as GlobalEvents
import Internal.Msg
import Internal.Options as Options exposing (cs, styled, many, when)
import Svg.Attributes as Svg
import Svg exposing (path)


update : (Msg -> m) -> Msg -> Model -> ( Maybe Model, Cmd m )
update _ msg model =
    case msg of
        NoOp ->
            ( Nothing, Cmd.none )

        SetFocus focus ->
            ( Just { model | isFocused = focus }, Cmd.none )

        Init lastKnownState state ->
            let
              animation =
                lastKnownState
                |> Maybe.andThen (flip animationState state)
            in
            ( Just
              { model
                | lastKnownState = Just state
                , animation = animation
              }
            ,
              Cmd.none
            )

        AnimationEnd ->
            ( Just { model | animation = Nothing }, Cmd.none )


type alias Config m =
    { state : Maybe State
    , disabled : Bool
    , nativeControl : List (Options.Property () m)
    }


defaultConfig : Config m
defaultConfig =
    { state = Nothing
    , disabled = False
    , nativeControl = []
    }


type alias Property m =
    Options.Property (Config m) m


disabled : Property m
disabled =
    Options.option (\ config -> { config | disabled = True })


type alias State =
    Internal.Checkbox.Model.State


checked : Bool -> Property m
checked value =
    let
        state =
            if value then Checked else Unchecked
    in
    Options.option (\ config -> { config | state = Just state })


nativeControl : List (Options.Property () m) -> Property m
nativeControl =
    Options.nativeControl


checkbox : (Msg -> m) -> Model -> List (Property m) -> List (Html m) -> Html m
checkbox lift model options _ =
    let
        ({ config } as summary) =
            Options.collect defaultConfig options

        animationClass animation =
          case animation of
            Just UncheckedChecked ->
              cs "mdc-checkbox--anim-unchecked-checked"

            Just UncheckedIndeterminate ->
              cs "mdc-checkbox--anim-unchecked-indeterminate"

            Just CheckedUnchecked ->
              cs "mdc-checkbox--anim-checked-unchecked"

            Just CheckedIndeterminate ->
              cs "mdc-checkbox--anim-checked-indeterminate"

            Just IndeterminateChecked ->
              cs "mdc-checkbox--anim-indeterminate-checked"

            Just IndeterminateUnchecked ->
              cs "mdc-checkbox--anim-indeterminate-unchecked"

            Nothing ->
              Options.nop

        currentState =
          model.lastKnownState
          |> Maybe.withDefault configState

        configState =
          config.state

        stateChangedOrUninitialized =
          (model.lastKnownState == Nothing) || (currentState /= configState)

        preventDefault =
            { preventDefault = True
            , stopPropagation = False
            }
    in
    Options.apply summary Html.div
    [ cs "mdc-checkbox mdc-checkbox--upgraded"
    , cs "mdc-checkbox--indeterminate" |> when (currentState == Nothing)
    , cs "mdc-checkbox--checked" |> when (currentState == Just Checked)
    , cs "mdc-checkbox--disabled" |> when config.disabled
    , animationClass model.animation
    , when stateChangedOrUninitialized <|
      GlobalEvents.onTick (Json.succeed (lift (Init model.lastKnownState configState)))
    , when (model.animation /= Nothing) <|
      Options.on "animationend" (Json.succeed (lift AnimationEnd))
    ]
    []
    [ Options.applyNativeControl summary
      Html.input
      [ cs "mdc-checkbox__native-control"
      , Options.many << List.map Options.attribute <|
        [ Html.type_ "checkbox"
        , Html.property "indeterminate" (Json.Encode.bool (currentState == Nothing))
        , Html.checked (currentState == Just Checked)
        , Html.disabled config.disabled
        ]
      , Options.onWithOptions "click" preventDefault (Json.succeed (lift NoOp))
      , Options.onWithOptions "change" preventDefault (Json.succeed (lift NoOp))
      , Options.onFocus (lift (SetFocus True))
      , Options.onBlur (lift (SetFocus False))
      ]
      []
    , styled Html.div
      [ cs "mdc-checkbox__background"
      ]
      [ Svg.svg
        [ Svg.class "mdc-checkbox__checkmark"
        , Svg.viewBox "0 0 24 24"
        ]
        [ path
          [ Svg.class "mdc-checkbox__checkmark-path"
          , Svg.fill "none"
          , Svg.stroke "white"
          , Svg.d "M1.73,12.91 8.1,19.28 22.79,4.59"
          ]
          [
          ]
        ]
      , styled Html.div
        [ cs "mdc-checkbox__mixedmark"
        ]
        []
      ]
    ]

animationState : Maybe State -> Maybe State -> Maybe Animation
animationState oldState state =
  case ( oldState, state ) of
      ( Just Unchecked, Nothing ) ->
        Just UncheckedIndeterminate

      ( Just Checked, Nothing ) ->
        Just CheckedIndeterminate

      ( Nothing, Just Checked ) ->
        Just IndeterminateChecked

      ( Nothing, Just Unchecked ) ->
        Just IndeterminateUnchecked

      ( Just Unchecked, Just Checked ) ->
        Just UncheckedChecked

      ( Just Checked, Just Unchecked ) ->
        Just CheckedUnchecked
      
      _ ->
        Nothing


type alias Store s =
    { s | checkbox : Indexed Model }


( get, set ) =
    Component.indexed .checkbox (\x y -> { y | checkbox = x }) defaultModel


view :
    (Internal.Msg.Msg m -> m)
    -> Index
    -> Store s
    -> List (Property m)
    -> List (Html m)
    -> Html m
view =
    Component.render get checkbox Internal.Msg.CheckboxMsg


react :
    (Internal.Msg.Msg m -> m)
    -> Msg
    -> Index
    -> Store s
    -> ( Maybe (Store s), Cmd m )
react =
    Component.react get set Internal.Msg.CheckboxMsg update
    -- TODO: make react always like this ^^^^, don't use generalise?
