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
        }
        return URL(string: address)!
    }

    func searchURL(for query: String) -> URL? {
        var url = URLComponents()
        url.scheme = "https"

        switch self {
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
