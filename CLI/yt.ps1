param (
    [Parameter(mandatory=$true)]
    $url
)

yt-dlp "$url" -o "%(title)s-%(id)s.%(ext)s"