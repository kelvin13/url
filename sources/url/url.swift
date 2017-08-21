public 
struct URL
{
    //   foo://taylor@example.com:1989/over/there?with=hellagood#hair
    //   \_/   \_____________________/\_________/ \____________/ \__/
    //    |               |                |              |        |
    // scheme         authority           path          query   fragment

    public 
    struct QueryItem 
    {
        public
        var name:String, 
            value:String?
    }
    
    public
    struct Components
    {
        public private(set)
        var scheme:Range<Int>?,
            user:Range<Int>?,
            host:Range<Int>?,
            port:Range<Int>?,
            path:Range<Int>,
            query:Range<Int>?,
            fragment:Range<Int>?

        // only the scheme is guaranteed to be well-formed
        init(string:[UInt8])
        {
            var active:Range<Int> = 0 ..< string.count

            // 1. isolate the fragment '\(#(.*))?\'
            if let hashtag:Int = string.index(of: 35) // '#'
            {
                self.fragment = hashtag + 1 ..< active.upperBound
                active        = active.lowerBound ..< hashtag
            }

            // 2. isolate the query '\(\?([^#]*))?\'
            if let question:Int = string.index(of: 63) // "?"
            {
                self.query = question + 1 ..< active.upperBound
                active     = active.lowerBound ..< question
            }
            
            // 3. isolate the scheme '\(([^:/?#]+):)?\'
            //    well-formed if: ALPHA *( ALPHA | DIGIT | '+' | '-' | '.' )
            if let  first:UInt8 = string.first,
                    first.is_alpha
            {
                for i:Int in CountableRange(active)
                {
                    let char:UInt8 = string[i]

                    if char == 58 // ':'
                    {
                        self.scheme = active.lowerBound ..< i
                        active      = i + 1 ..< active.upperBound
                        break
                    }
                    else if !char.is_scheme_char
                    {
                        break
                    }
                }
            }
            
            // 4. isolate the authority '\(//([^/?#]*))?\'
            if  active.count >= 2,
                string[active.lowerBound ..< active.lowerBound + 2] == [47, 47] // "//"
            {
                active = active.lowerBound + 2 ..< active.upperBound

                var authority:Range<Int>
                if let slash:Int = string[active].index(of: 47) // '/'
                {
                    authority = active.lowerBound ..< slash
                }
                else
                {
                    authority = active
                }
                
                // 4.a. isolate the user '\*( unreserved / pct-encoded / sub-delims / ":" ) "@"\'
                if let at:Int = string[authority].index(of: 64) // '@'
                {
                    self.user = authority.lowerBound ..< at
                    authority = at + 1 ..< authority.upperBound
                }
                
                // 4.b. isolate the port (the rightmost colon that occurs after
                // a ']', if present)
                
                // 4.c. the remainder is the host
                if let  colon:Int = string[authority].reversed().index(of: 58),
                        colon < string[authority].reversed().index(of: 93) ?? Int.max
                {
                    self.port = authority.upperBound - colon ..< authority.upperBound
                    self.host = authority.lowerBound ..< authority.upperBound - colon - 1
                }
                else
                {
                    self.host = authority
                }
                
                active = authority.upperBound ..< active.upperBound
            }
            
            // 5. remainder is the path
            self.path = active
        }
    }

    public 
    enum Scheme:CustomStringConvertible
    {
        case uncommon(String),
             http,
             https,
             file,
             data,
             ftp 
        
        public 
        var description:String 
        {
            switch self 
            {
            case let .uncommon(scheme):
                return scheme 
            case .http:
                return "http"
            case .https:
                return "https"
            case .file:
                return "file"
            case .data:
                return "data"
            case .ftp:
                return "ftp"
            }
        }
    }

    private 
    enum _Scheme
    {
        case uncommon,
             http,
             https,
             file,
             data,
             ftp
    }

    public 
    enum Host:CustomStringConvertible, CustomDebugStringConvertible
    {
        case ipv4((UInt8, UInt8, UInt8, UInt8)),
             ipv6((UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16)),
             registered(String)
        
        public
        var description:String 
        {
            switch self 
            {
            case let .ipv4(address):
                return "\(address.0).\(address.1).\(address.2).\(address.3)" 
            case let .ipv6(address):
                return "\(String(address.0, radix: 16)):\(String(address.1, radix: 16)):\(String(address.2, radix: 16)):\(String(address.3, radix: 16)):\(String(address.4, radix: 16)):\(String(address.5, radix: 16)):\(String(address.6, radix: 16)):\(String(address.7, radix: 16))" 
            case let .registered(name):
                return name
            }
        }
        
        public
        var debugDescription:String 
        {
            switch self 
            {
            case .ipv4:
                return "[ipv4] \(self.description)" 
            case .ipv6:
                return "[ipv6] \(self.description)" 
            case let .registered(name):
                return name
            }
        }
    }
    
    private 
    enum _Host
    {
        case ipv4((UInt8, UInt8, UInt8, UInt8)),
             ipv6((UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16)),
             registered
    }

    private
    enum Flags
    {
        static
        let user:UInt8      = 0b0000_0001,
            query:UInt8     = 0b0000_0010, 
            fragment:UInt8  = 0b0000_0100, 
            
            directory:UInt8 = 0b0000_1000
    }

    // internally stored percent-encoded so less conversion is needed when
    // this type is simply used to store (and not modify) a url.
    private
    var core:[UInt8] = [], 
        _scheme:_Scheme?, 
        flags:UInt8 = 0,
        _host:_Host?, 
        _port:Int?

    // an empty first path segment signifies an absolute path
    private
    var ranges:[Range<Int>] = []
    // { scheme, user, host, path_1, path_2 ... path_n, query, fragment }

    // “flags”
    public 
    var has_directory_path:Bool 
    {
        return self.flags & Flags.directory != 0
    }
    
    private
    var has_scheme:Bool
    {
        if let scheme:_Scheme = self._scheme
        {
            return scheme == .uncommon
        } 
        else 
        {
            return false
        }
    }

    private 
    var has_user:Bool
    {
        return self.flags & Flags.user != 0
    }
    
    private
    var has_host:Bool
    {
        if let   host:_Host = self._host, 
           case .registered = host 
        {
            return true
        }
        else 
        {
            return false
        }
    }

    private
    var has_query:Bool
    {
        return self.flags & Flags.query != 0
    }
    
    private
    var has_fragment:Bool
    {
        return self.flags & Flags.fragment != 0
    }
    
    // outward facing properties 
    public 
    var scheme:Scheme? 
    {
        guard let scheme:_Scheme = self._scheme 
        else 
        {
            return nil
        }
        
        switch scheme
        {
        case .uncommon: 
            // scheme cannot contain percent escapes
            return .uncommon(String(decoding: self.core[self.ranges[0]], 
                                    as: Unicode.UTF8.self))
        case .http:
            return .http 
        case .https:
            return .https 
        case .file:
            return .file 
        case .data:
            return .data 
        case .ftp:
            return .ftp
        }
    }
    
    public 
    var user:String? 
    {
        return self.has_user ? 
            URL.unescape(self.core[self.ranges[self.has_scheme ? 1 : 0]]) : nil
    }
    
    public 
    var host:Host? 
    {
        guard let host:_Host = self._host
        else 
        {
            return nil
        }
        
        switch host
        {
        case let .ipv4(address): 
            return .ipv4(address)
        case let .ipv6(address): 
            return .ipv6(address)
        case .registered:
            let index:Int = (self.has_scheme ? 1 : 0) + (self.has_user ? 1 : 0)
            return .registered(URL.unescape(self.core[self.ranges[index]]))
        }
    }
    
    public 
    var port:Int? 
    {
        return self._port
    }
    
    public 
    var path_segments:[String] 
    {
        let prefix:Int = (self.has_scheme   ? 1 : 0) + 
                         (self.has_user     ? 1 : 0) + 
                         (self.has_host     ? 1 : 0) , 
        
            suffix:Int = (self.has_query    ? 1 : 0) + (self.has_fragment ? 1 : 0)
        
        let r:Range<Int> = prefix ..< self.ranges.count - suffix 
        guard r.count > 0 
        else 
        {
            return []
        } 
        
        var segments:[String] = self.ranges[r].map{ URL.unescape(self.core[$0]) }
        if segments[0] == "" 
        {
            segments[0] = "/"
        }
        
        return segments
    }
    
    public 
    var query:String? 
    {
        return self.has_query ? 
            URL.unescape(self.core[self.ranges[self.ranges.count - (self.has_fragment ? 2 : 1)]]) : 
            nil
    }
    
    public 
    var fragment:String? 
    {
        return self.has_fragment ? URL.unescape(self.core[self.ranges.last!]) : nil
    }


    private
    init?(string:[UInt8], components:Components)
    {
        if let scheme:Range<Int> = components.scheme
        {
            if      scheme.count == 3,
                        string[scheme] == [102, 116, 112] // "ftp"
            {
                    self._scheme = .ftp
            }
            else if scheme.count == 4
            {
                if      string[scheme] == [104, 116, 116, 112] // "http"
                {
                    self._scheme = .http
                }
                else if string[scheme] == [102, 105, 108, 101] // "file"
                {
                    self._scheme = .file
                }
                else if string[scheme] == [100,  97, 116,  97] // "data"
                {
                    self._scheme = .data
                }
                else
                {
                    self._scheme = .uncommon
                }
            }
            else if scheme.count == 5,
                        string[scheme] == [104, 116, 116, 112, 115] // "https"
            {
                    self._scheme = .https
            }
            else
            {
                    self._scheme = .uncommon
            }
            
            if self._scheme == .uncommon 
            {
                self.ranges.append(0 ..< scheme.count)
                self.core.append(contentsOf: string[scheme])
            }
        }

        if let user:Range<Int> = components.user 
        {
            self.flags |= Flags.user 
            
            // validate user string 
            // *( unreserved / pct-encoded / sub-delims / ":" )
            for char:UInt8 in string[user] 
            {
                guard char.is_user_char 
                else 
                {
                    self.flags &= ~Flags.user 
                    break
                }
            }
            
            if self.has_user 
            {
                guard self.push_to_core(validating: string[user])
                else 
                {
                    return nil
                }
            }
        }
        
        if let host:Range<Int> = components.host 
        {
            @inline(__always) 
            func _parse_ipv4(_ ipv4:ArraySlice<UInt8>, suppress_errors:Bool = false) 
                -> (UInt8, UInt8, UInt8, UInt8)?
            {
                var pieces:[UInt8] = []
                    pieces.reserveCapacity(4)
                
                for piece:ArraySlice<UInt8> in ipv4.split(separator: 46) // '.' 
                {
                    guard let decimal:Int = 
                        URL.decimal_to_int(piece, suppress_errors: suppress_errors) 
                    else 
                    {
                        return nil
                    }
                    
                    guard let piece_value:UInt8 = UInt8(exactly: decimal) 
                    else 
                    {
                        if !suppress_errors 
                        {
                            print_error("ipv4 piece '\(decimal)' overflows UInt8") 
                        }

                        return nil
                    }
                    
                    pieces.append(piece_value)
                }
                
                guard pieces.count == 4 
                else 
                {
                    if !suppress_errors 
                    {
                        print_error("ipv4 address must contain exactly 4 pieces") 
                    }
                    
                    return nil
                }
                
                return (pieces[0], pieces[1], pieces[2], pieces[3])
            }
            
            // case 1: IP literal
            // "[" ( IPv6address / IPvFuture  ) "]"
            if  host.count >= 2, 
                string[host.lowerBound] == 91 // '[' 
            {
                guard string[host.upperBound - 1] == 93 // ']' 
                else 
                {
                    print_error("ipv6 literal is missing closing square bracket") 
                    
                    return nil
                }
                
                // case 1.a: IPvFuture literal (unsupported)
                if string[host.lowerBound + 1] == 118 // 'v' 
                {
                    print_error("ip version > 6 literals are unsupported") 
                    
                    return nil
                }
                // case 1.b: IPv6 literal 
                else 
                {
                    let address:Range<Int> = host.lowerBound + 1 ..< host.upperBound - 1
                    
                    var pieces:[UInt16]    = [],
                        elision:Int?       = nil, 
                        i:Int              = address.lowerBound
                    
                    pieces.reserveCapacity(8)
                    
                    for j:Int in CountableRange(address)
                    {
                        let char:UInt8 = string[j] 
                        if char == 58 // ':' 
                        {
                            if i < j 
                            {
                                guard pieces.count > 0 || i == address.lowerBound 
                                else 
                                {
                                    print_error("ipv6 literal cannot begin with a single colon")

                                    return nil
                                }
                                
                                guard let value:UInt16 = URL.hex_to_int(string[i ..< j]) 
                                else 
                                {
                                    return nil
                                }
                                
                                pieces.append(value)
                            }
                            else if i != address.lowerBound 
                            {
                                // there is always a '[' before address.lowerBound 
                                // so there will never be an index error
                                guard string[j - 2] != 58 
                                else 
                                {
                                    print_error("three or more consecutive colons cannot appear in ipv6 literal")
                                    
                                    return nil
                                }
                                
                                guard elision == nil
                                else 
                                {
                                    print_error("more than one elision cannot appear in ipv6 literal")
                                    
                                    return nil
                                }
                                
                                elision = pieces.count
                            }
                            
                            i = j + 1
                        }
                        else if char == 46 // '.' 
                        {
                            guard let ipv4:(UInt8, UInt8, UInt8, UInt8) = 
                                _parse_ipv4(string[i ..< address.upperBound]) 
                            else 
                            {
                                return nil
                            }
                            
                            pieces.append(UInt16(ipv4.0) &<< 8 | UInt16(ipv4.1)) 
                            pieces.append(UInt16(ipv4.2) &<< 8 | UInt16(ipv4.3))
                            
                            i = address.upperBound + 1 // sentinel value
                            break
                        }
                    }
                    
                    if i < address.upperBound 
                    {
                        guard let value:UInt16 = URL.hex_to_int(string[i ..< address.upperBound]) 
                        else 
                        {
                            return nil
                        }
                        
                        pieces.append(value)
                    }
                    else if i == address.upperBound
                    {
                        guard elision ?? -1 == pieces.count 
                        else 
                        {
                            print_error("ipv6 literal cannot end with a single colon")
                            
                            return nil
                        }
                    }
                    
                    if let elision:Int = elision 
                    {
                        guard pieces.count < 8 
                        else 
                        {
                            print_error("elided ipv6 literal contains too many pieces")
                            
                            return nil
                        }
                        
                        let filler:Repeated<UInt16> = repeatElement(0, count: 8 - pieces.count)
                        pieces.insert(contentsOf: filler, at: elision)
                    }
                    else 
                    {
                        guard pieces.count == 8 
                        else 
                        {
                            print_error("ipv6 literal must contain exactly 8 pieces")
                            
                            return nil
                        }
                    }
                    
                    self._host  = .ipv6((pieces[0], 
                                        pieces[1], 
                                        pieces[2], 
                                        pieces[3], 
                                        pieces[4], 
                                        pieces[5], 
                                        pieces[6], 
                                        pieces[7]))
                }
            }
            else 
            {
                // validate host name
                // *( unreserved / pct-encoded / sub-delims )
                for char:UInt8 in string[host] 
                {
                    
                    guard char.is_reg_char 
                    else 
                    {
                        print_error("character '\(Unicode.Scalar(char))' not allowed in host name") 
                        
                        return nil
                    }
                }
                
                // case 2: IPv4 literal
                if let ipv4:(UInt8, UInt8, UInt8, UInt8) = 
                    _parse_ipv4(string[host], suppress_errors: true) 
                {
                    self._host = .ipv4(ipv4)
                } 
                // case 3: registered name
                else 
                {
                    guard self.push_to_core(validating: string[host])
                    else 
                    {
                        return nil
                    }
                    
                    self._host = .registered 
                }
            }
        }
        
        if let port:Range<Int> = components.port 
        {
            guard let port_number:Int = URL.decimal_to_int(string[port]) 
            else 
            {
                print_error("port '\(String(decoding: string[port], as: Unicode.UTF8.self))' must be a valid decimal number") 
                
                return nil
            }
            
            self._port = port_number
        }
        
        if components.path.count > 0
        {
            // validate path string
            // *(unreserved / pct-encoded / sub-delims / ":" / "@" / "/")
            for char:UInt8 in string[components.path] 
            {
                guard char.is_path_char 
                else 
                {
                    print_error("character '\(Unicode.Scalar(char))' not allowed in path") 
                    
                    return nil
                }
            }
            
            for segment:ArraySlice<UInt8> in 
                string[components.path].split(  separator: 47, 
                                                omittingEmptySubsequences: false) 
            {
                guard self.push_to_core(validating: segment)
                else 
                {
                    return nil
                }
            }
            
            // split is guaranteed to have added at least one new range
            if self.ranges.last!.count == 0 
            {
                self.flags |= Flags.directory 
                self.ranges.removeLast() 
            }
        }
        
        if let query:Range<Int> = components.query 
        {
            // validate query string
            // *(unreserved / pct-encoded / sub-delims / ":" / "@" / "/" / "?")
            for char:UInt8 in string[query] 
            {
                guard char.is_query_frag_char 
                else 
                {
                    print_error("character '\(Unicode.Scalar(char))' not allowed in query") 
                    
                    return nil
                }
            }
            
            self.flags |= Flags.query 
            guard self.push_to_core(validating: string[query]) 
            else 
            {
                return nil
            }
        }
        
        if let fragment:Range<Int> = components.fragment 
        {
            // validate fragment string
            // *(unreserved / pct-encoded / sub-delims / ":" / "@" / "/" / "?")
            for char:UInt8 in string[fragment] 
            {
                guard char.is_query_frag_char 
                else 
                {
                    print_error("character '\(Unicode.Scalar(char))' not allowed in fragment") 
                    
                    return nil
                }
            }
            
            self.flags |= Flags.fragment 
            guard self.push_to_core(validating: string[fragment])
            else 
            {
                return nil
            }
        }
    }
    
    public 
    init?(_ string:String) 
    {
        let utf8:[UInt8] = Array(string.utf8)
        let components:Components = Components(string: utf8) 
        self.init(string: utf8, components: components)
    }
    
    // pushes string to self._core and creates a corresponding record in self._ranges 
    // validates all percent encoded sequences 
    // returns true if successful
    private mutating 
    func push_to_core(validating string:ArraySlice<UInt8>) -> Bool
    {
        var hex_digits:Int   = 0

        for (i, char):(Int, UInt8) in string.enumerated()
        {
            if hex_digits == 0
            {
                // '%' must be followed by at least 2 more characters, and they
                // must be hex digits
                if char == 37 // '%'
                {
                    guard i + 2 < string.count
                    else
                    {
                        print_error("percent encoding must contain 2 hex digits")
                        return false
                    }

                    hex_digits = 2
                }
            }
            else if char.is_hex
            {
                hex_digits -= 1
            }
            else
            {
                print_error("invalid hex digit '\(Unicode.Scalar(char))'")
                return false
            }
        }
        
        self.ranges.append(self.core.count ..< self.core.count + string.count)
        self.core.append(contentsOf: string) 

        return true
    }
    
    private static 
    func hex_to_int(_ str:ArraySlice<UInt8>) -> UInt16? 
    {
        guard str.count <= 4 
        else 
        {
            print_error("hex number '\(String(decoding: str, as: Unicode.UTF8.self))' overflows UInt16")
            return nil
        }
        
        var value:UInt16 = 0
        for digit:UInt8 in str 
        {
            guard let digit_value:UInt8 = digit.hex_value 
            else 
            {
                print_error("invalid hex digit '\(Unicode.Scalar(digit))'")
                return nil
            }
            
            value = value &<< 4 | UInt16(digit_value)
        }
        
        return value
    }
    
    private static 
    func decimal_to_int(_ str:ArraySlice<UInt8>, suppress_errors:Bool = false) 
        -> Int? 
    {
        var value:Int = 0
        for digit:UInt8 in str 
        {
            let digit_value:Int = Int(digit) - 48 // '0'
            guard 0 ..< 10 ~= digit_value
            else 
            {
                if !suppress_errors 
                {
                    print_error("invalid decimal digit '\(Unicode.Scalar(digit))'")
                }

                return nil
            }
            
            value = value * 10 + digit_value
        }
        
        return value
    }
    
    private static 
    func unescape(_ str:ArraySlice<UInt8>) -> String 
    {
        // unescaped string must be smaller or equal in length
        var i:Int = str.startIndex, 
            unescaped:[UInt8] = []
            unescaped.reserveCapacity(str.count) 
        
        while i < str.endIndex 
        {
            let char:UInt8 = str[i] 
            if char == 37  // '%' 
            {
                // we’ve already validated the escape sequences, so there is 
                // guaranteed to be at least 2 hex digits after it
                unescaped.append(str[i + 1].hex_value! << 4 | str[i + 2].hex_value!)
                i += 3
            }
            else 
            {
                unescaped.append(char)
                i += 1
            }
        }
        
        return String(decoding: unescaped, as: Unicode.UTF8.self)
    }
}
extension URL:CustomDebugStringConvertible 
{
    public
    var debugDescription:String 
    {
        return "URL{scheme: \(self.scheme?.description ?? "nil"), user: \(self.user ?? "nil"), host: \(self.host?.debugDescription ?? "nil"), port: \(self.port?.description ?? "nil"), path: \(self.path_segments), query: \(self.query ?? "nil"), fragment: \(self.fragment ?? "nil")}"
    }
}

@inline(__always)
func print_error(_ message:String) 
{
    if _isDebugAssertConfiguration()
    {
        print(message)
    }
}

extension UInt8
{
    /*
    nul   0    
    soh   1    
    stx   2    
    etx   3    
    eot   4    
    enq   5    
    ack   6    
    bel   7    
    bs    8    
    ht    9    
    nl   10    
    vt   11    
    np   12    
    cr   13    
    so   14    
    si   15    
    dle  16    
    dc1  17    
    dc2  18    
    dc3  19    
    dc4  20    
    nak  21    
    syn  22    
    etb  23    
    can  24    
    em   25    
    sub  26    
    esc  27    
    fs   28    
    gs   29    
    rs   30    
    us   31    
    sp   32    
    '!'  33             subdelm
    '"'  34    
    '#'  35    
    '$'  36             subdelm
    '%'  37     percent
    '&'  38             subdelm 
    '''  39             subdelm
    '('  40             subdelm
    ')'  41             subdelm
    '*'  42             subdelm
    '+'  43             subdelm
    ','  44             subdelm
    '-'  45     unrsrvd
    '.'  46     unrsrvd
    '/'  47    
    '0'  48     unrsrvd
    '1'  49     unrsrvd
    '2'  50     unrsrvd
    '3'  51     unrsrvd
    '4'  52     unrsrvd
    '5'  53     unrsrvd
    '6'  54     unrsrvd
    '7'  55     unrsrvd
    '8'  56     unrsrvd
    '9'  57     unrsrvd
    ':'  58    
    ';'  59             subdelm
    '<'  60    
    '='  61             subdelm
    '>'  62    
    '?'  63    
    '@'  64    
    'A'  65     unrsrvd
    'B'  66     unrsrvd
    'C'  67     unrsrvd
    'D'  68     unrsrvd
    'E'  69     unrsrvd
    'F'  70     unrsrvd
    'G'  71     unrsrvd
    'H'  72     unrsrvd
    'I'  73     unrsrvd
    'J'  74     unrsrvd
    'K'  75     unrsrvd
    'L'  76     unrsrvd
    'M'  77     unrsrvd
    'N'  78     unrsrvd
    'O'  79     unrsrvd
    'P'  80     unrsrvd
    'Q'  81     unrsrvd
    'R'  82     unrsrvd
    'S'  83     unrsrvd
    'T'  84     unrsrvd
    'U'  85     unrsrvd
    'V'  86     unrsrvd
    'W'  87     unrsrvd
    'X'  88     unrsrvd
    'Y'  89     unrsrvd
    'Z'  90     unrsrvd
    '['  91    
    '\'  92    
    ']'  93    
    '^'  94    
    '_'  95     unrsrvd
    '`'  96    
    'a'  97     unrsrvd
    'b'  98     unrsrvd
    'c'  99     unrsrvd
    'd' 100     unrsrvd
    'e' 101     unrsrvd
    'f' 102     unrsrvd
    'g' 103     unrsrvd
    'h' 104     unrsrvd
    'i' 105     unrsrvd
    'j' 106     unrsrvd
    'k' 107     unrsrvd
    'l' 108     unrsrvd
    'm' 109     unrsrvd
    'n' 110     unrsrvd
    'o' 111     unrsrvd
    'p' 112     unrsrvd
    'q' 113     unrsrvd
    'r' 114     unrsrvd
    's' 115     unrsrvd
    't' 116     unrsrvd
    'u' 117     unrsrvd
    'v' 118     unrsrvd
    'w' 119     unrsrvd
    'x' 120     unrsrvd
    'y' 121     unrsrvd
    'z' 122     unrsrvd
    '{' 123    
    '|' 124    
    '}' 125    
    '~' 126     unrsrvd
    del 127    
    */
    
    var is_scheme_char:Bool
    {
        return  48 ... 57  ~= self || // [0-9]
                self.is_alpha ||
                self == 43 || self == 45 || self == 46 // '+', '-', '.'
    }
    
    var is_user_char:Bool
    {
        // unrsrvd / percent / subdelm / ':'
        return  36 ... 46  ~= self || 
                48 ... 59  ~= self || 
                self.is_alpha ||
                self == 33 || self == 61 || self == 95 || self == 126
    }
    
    var is_reg_char:Bool
    {
        // unrsrvd / percent / subdelm 
        return  36 ... 46  ~= self || 
                48 ... 57  ~= self || // [0-9]
                self.is_alpha ||
                self == 33 || self == 59 || self == 61 || self == 95 || self == 126
    }
    
    var is_path_char:Bool
    {
        // unrsrvd / percent / subdelm / ':' / '@' / '/'
        return  36 ... 59  ~= self || 
                64 ... 90  ~= self || // [@-Z]
                97 ... 122 ~= self || // [a-z]
                self == 33 || self == 61 || self == 95 || self == 126
    }
    
    var is_query_frag_char:Bool
    {
        // unrsrvd / percent / subdelm / ':' / '@' / '/' / '?'
        return  36 ... 59  ~= self || 
                63 ... 90  ~= self || // [?-Z]
                97 ... 122 ~= self || // [a-z]
                self == 33 || self == 61 || self == 95 || self == 126
    }

    var is_alpha:Bool
    {
        return  65 ... 90  ~= self ||
                97 ... 122 ~= self
    }

    var is_hex:Bool
    {
        return  48 ...  57 ~= self ||
                65 ...  70 ~= self ||
                97 ... 102 ~= self
    }

    var hex_value:UInt8?
    {
        if      48 ...  57 ~= self
        {
            return self &- 48
        }
        else if 65 ...  70 ~= self
        {
            return self &- 65 &+ 10
        }
        else if 97 ... 102 ~= self
        {
            return self &- 97 &+ 10
        }
        else
        {
            return nil
        }
    }
}
