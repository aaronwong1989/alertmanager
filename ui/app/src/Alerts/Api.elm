module Alerts.Api exposing (alertDecoder, alertsDecoder, fetchAlerts, fetchReceivers)

import Alerts.Types exposing (Alert, Receiver)
import Json.Decode as Json exposing (..)
import Regex
import Utils.Api exposing (iso8601Time)
import Utils.Filter exposing (Filter, generateQueryString)
import Utils.Types exposing (ApiData)


escapeRegExp : String -> String
escapeRegExp text =
    let
        reg =
            Regex.fromString "/[-[\\]{}()*+?.,\\\\^$|#\\s]/g" |> Maybe.withDefault Regex.never
    in
    Regex.replace reg (.match >> (++) "\\") text


fetchReceivers : String -> Cmd (ApiData (List Receiver))
fetchReceivers apiUrl =
    Utils.Api.send
        (Utils.Api.get
            (apiUrl ++ "/receivers")
            (field "data" (list (Json.map (\receiver -> Receiver receiver (escapeRegExp receiver)) string)))
        )


fetchAlerts : String -> Filter -> Cmd (ApiData (List Alert))
fetchAlerts apiUrl filter =
    let
        url =
            String.join "/" [ apiUrl, "alerts" ++ generateQueryString filter ]
    in
    Utils.Api.send (Utils.Api.get url alertsDecoder)


alertsDecoder : Json.Decoder (List Alert)
alertsDecoder =
    Json.list alertDecoder
        -- populate alerts with ids:
        |> Json.map (List.indexedMap (String.fromInt >> (|>)))
        |> field "data"


{-| TODO: decode alert id when provided
-}
alertDecoder : Json.Decoder (String -> Alert)
alertDecoder =
    Json.map6 Alert
        (Json.maybe (field "annotations" (Json.keyValuePairs Json.string))
            |> andThen (Maybe.withDefault [] >> Json.succeed)
        )
        (field "labels" (Json.keyValuePairs Json.string))
        (Json.maybe (Json.at [ "status", "silencedBy", "0" ] Json.string))
        (Json.maybe (Json.at [ "status", "inhibitedBy", "0" ] Json.string)
            |> Json.map ((/=) Nothing)
        )
        (field "startsAt" iso8601Time)
        (field "generatorURL" Json.string)
