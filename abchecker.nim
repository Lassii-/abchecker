import httpclient, htmlparser, xmltree, os, osproc, smtp, json, streams, times,
        strformat, strutils, math, random
#[
    Read necessary data from a json-file
    json-file contents should be as follows
    {
    "sender": "bot's email address",
    "password": "bot's email password",
    "receiver": "email address that bot sends the emails to",
    "url": "https://animebytes.tv/register/apply",
    "useragent": "User-agent that bot uses when connection to the url, ie. Mozilla/5.0 (X11; Linux x86_64; rv:82.0) Gecko/20100101 Firefox/82.0"
    }
    and be in the same folder with the executable file and be called secrets.json
]#
proc read_secrets(): JsonNode =
    try:
        let jsonfile = newFileStream("secrets.json", fmRead)
        let parsedJson = parseJson(jsonfile)
        jsonfile.close()
        return parsedJson
    except IOError:
        echo "Can't open secrets.json"
var parsedJson = read_secrets()
#[
    Send the email, takes smpt.Message as the parameter
    See https://nim-lang.org/docs/smtp.html & https://nim-lang.org/docs/smtp.html#Message
]#
var smtpConn = newSmtp(useSsl = true, debug = false)
proc send_email(message: Message) =
    smtpConn.connect("smtp.gmail.com", Port 465)
    smtpConn.auth(parsedJson["sender"].getStr(), parsedJson["password"].getStr())
    smtpConn.sendmail(parsedJson["sender"].getStr(), @[parsedJson[
            "receiver"].getStr()], $message)
    smtpConn.close()

#[
    Gets the title of the website being polled and returns it
    In case of a failure, sleep 10 seconds and try again
]#
var client = newHttpClient(userAgent = parsedJson["useragent"].getStr())
proc get_title(): string {.discardable.} =
    try:
        let page = client.getContent(parsedJson["url"].getStr())
        client.close()
        let html = parseHtml(newStringStream(page))
        let title = $(innerText(html.findAll("title")[0]))
        return title
    except:
        sleep(10000)
        get_title()

#[
    Checks the title pulled from the website and decides whether to email based on the result
    Takes an integer for how long to sleep between checks, give a number in milliseconds and 
    an integer for how many status prints before the screen is cleared.
]#
var screenClear = 0
proc check_status(sleeptimer: int, screenClearCount: int) =
    var title = get_title()
    var minutes = int((sleeptimer/(1000*60)) mod 60)
    var seconds = int((sleeptimer/1000) mod 60)
    if screenClear == screenClearCount:
        screenClear = 0
        discard execCmd "clear"
    if title == parsedJson[
                "title"].getStr():
        echo "Applications currently \e[1;91mclosed\e[00m.\nChecking status again in {minutes} minutes and {seconds} seconds. Time when last checked was ".fmt &
                $now().format("HH:mm")
    else:
        echo "Applications currently \e[1;92mopen\e[00m.\nChecking status again in {minutes} minutes and {seconds} seconds. Time when last checked was ".fmt &
                $now().format("HH:mm")
        send_email(createMessage(title, "Applications open", @[parsedJson[
                "receiver"].getStr()]))
    screenClear = screenClear + 1
    sleep(sleeptimer)

#[
    Main proc
]#
proc main() =
    # Initialize the random number generator
    randomize()
    echo "Welcome to the AnimeBytes Application Checker!"
    while(true):
        # Randomize between 5-15 minutes to recheck
        check_status(rand(300000..900000), 10)

main()
