import URL 

public 
let test_urls:[String] = 
[
    "https://alihudson@taylorswift.com:1989/events/past%20tours/?new-user=true#dates", 
    "https://alihudson@13.22.189.15:1989/events/past%20tours/?new-user=true#dates",
    "https://alihudson@[CA:FE::BABE:13.22.189.15]:1989/events/past%20tours/?new-user=true#dates",
    "/events/past%20tours/?new-user=true#dates", 
    "events/past%20tours/?new-user=true#dates", 
    "https:", 
    "https://"
]

public 
func test_url(_ string:String) 
{
    print("test url: \(string)")
    guard let url:URL = URL(string) 
    else 
    {
        return
    }
    
    print(url)
}
