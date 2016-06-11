
function get-shortName($package) {
    $m = $package -match "(?<shortname>.*?)(,(?<specificversion>.+)){0,1}$"
    return $Matches["shortname"]
}