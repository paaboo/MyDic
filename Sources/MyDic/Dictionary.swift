import Foundation

enum Dictionary: String, CaseIterable, Identifiable, Codable {
    case english = "영어"
    case korean = "국어"
    case hanja = "한자"
    case encyclopedia = "백과사전"
    case technology = "기술백과"
    case terminology = "첨단기술용어"
    case scholarly = "학술·논문"
    case wikipedia = "Wikipedia"
    case papago = "Papago"
    case chatGPT = "ChatGPT"
    case gemini = "Gemini"

    var id: Self { self }

    var example: String {
        switch self {
        case .english: "resilient"
        case .korean: "되레"
        case .hanja: "靑"
        case .encyclopedia: "산업혁명"
        case .technology: "벡터 데이터베이스"
        case .terminology: "검색 증강 생성"
        case .scholarly: "machine learning"
        case .wikipedia: "Seoul"
        case .papago: "Hello"
        case .chatGPT, .gemini: "검색 증강 생성이란?"
        }
    }

    var source: String {
        switch self {
        case .english, .korean, .hanja: "네이버 사전"
        case .encyclopedia: "한국어 위키백과"
        case .technology: "IBM Think · 웹 검색"
        case .terminology: "TTA 정보통신용어사전"
        case .scholarly: "Google Scholar"
        case .wikipedia: "English Wikipedia"
        case .papago: "네이버 Papago"
        case .chatGPT: "ChatGPT"
        case .gemini: "Google Gemini"
        }
    }

    var homeURL: URL {
        let address = switch self {
        case .english: "https://en.dict.naver.com/"
        case .korean: "https://ko.dict.naver.com/"
        case .hanja: "https://hanja.dict.naver.com/"
        case .encyclopedia: "https://ko.m.wikipedia.org/"
        case .technology: "https://www.ibm.com/kr-ko/think/topics"
        case .terminology: "https://terms.tta.or.kr/mobile/main.do"
        case .scholarly: "https://scholar.google.com/?hl=ko"
        case .wikipedia: "https://en.m.wikipedia.org/"
        case .papago: "https://papago.naver.com/"
        case .chatGPT: "https://chatgpt.com/"
        case .gemini: "https://gemini.google.com/app"
        }
        return URL(string: address)!
    }

    func searchURL(for query: String) -> URL? {
        var url = URLComponents()
        url.scheme = "https"

        switch self {
        case .chatGPT:
            url.host = "chatgpt.com"
            url.path = "/"
            let prompt = """
            다음 입력을 사전 및 번역 용도로 설명해 주세요.
            단어 또는 용어라면 주요 뜻, 품사(해당하는 경우), 한국어 번역과 짧은 예문 1개를 알려 주세요.
            한국어 입력이라면 영어 번역도 함께 알려 주세요.
            문장이라면 자연스러운 한국어 번역(한국어 문장은 영어 번역)과 핵심 표현을 짧게 설명해 주세요.
            확실하지 않은 뜻은 불확실하다고 밝혀 주세요. 답변은 한국어로 간결하게 작성해 주세요.
            아래 구분선 이후는 설명할 입력입니다.
            ---
            \(query)
            """
            url.queryItems = [URLQueryItem(name: "q", value: prompt)]
        case .gemini:
            return homeURL
        case .papago:
            url.host = "papago.naver.com"
            url.path = "/"
            url.queryItems = [
                URLQueryItem(name: "sk", value: "auto"),
                URLQueryItem(name: "tk", value: "ko"),
                URLQueryItem(name: "st", value: query)
            ]
        case .english, .korean, .hanja:
            switch self {
            case .english: url.host = "en.dict.naver.com"
            case .korean: url.host = "ko.dict.naver.com"
            default: url.host = "hanja.dict.naver.com"
            }
            url.path = "/"
            var route = URLComponents()
            route.path = "/search"
            route.queryItems = [URLQueryItem(name: "query", value: query)]
            // WebKit sends the fragment to the provider's client-side router.
            url.percentEncodedFragment = route.percentEncodedQuery.map {
                "/search?" + $0.replacingOccurrences(of: "+", with: "%2B")
            }

        case .encyclopedia, .wikipedia:
            url.host = self == .encyclopedia ? "ko.m.wikipedia.org" : "en.m.wikipedia.org"
            url.path = "/w/index.php"
            url.queryItems = [
                URLQueryItem(name: "title", value: "Special:Search"),
                URLQueryItem(name: "search", value: query)
            ]

        case .technology:
            url.host = "www.google.com"
            url.path = "/search"
            url.queryItems = [URLQueryItem(name: "q", value: "site:www.ibm.com/kr-ko/think/topics \(query)")]

        case .terminology:
            url.host = "terms.tta.or.kr"
            url.path = "/mobile/searchList.do"
            url.queryItems = [
                URLQueryItem(name: "searchTerm", value: query),
                URLQueryItem(name: "searchContent", value: "conts01"),
                URLQueryItem(name: "searchRange", value: "all"),
                URLQueryItem(name: "listCount", value: "10"),
                URLQueryItem(name: "listPage", value: "1"),
                URLQueryItem(name: "orderby", value: "WEIGHT"),
                URLQueryItem(name: "reFlag", value: "N"),
                URLQueryItem(name: "orderbyOption", value: "TRUE"),
                URLQueryItem(name: "firstWord", value: "N"),
                URLQueryItem(name: "searchCate", value: "bigram")
            ]

        case .scholarly:
            url.host = "scholar.google.com"
            url.path = "/scholar"
            url.queryItems = [
                URLQueryItem(name: "hl", value: "ko"),
                URLQueryItem(name: "q", value: query)
            ]
        }

        url.percentEncodedQuery = url.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        return url.url
    }
}
