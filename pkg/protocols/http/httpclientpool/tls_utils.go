package httpclientpool

import (
	"net/http"
	"net/http/cookiejar"
	"net/url"

	fhttp "github.com/bogdanfinn/fhttp"
	"github.com/bogdanfinn/tls-client/profiles"
)

type CookieJarAdapter struct {
	jar *cookiejar.Jar
}

func (j *CookieJarAdapter) SetCookies(u *url.URL, cookies []*fhttp.Cookie) {
	httpCookies := make([]*http.Cookie, len(cookies))
	for i, c := range cookies {
		httpCookies[i] = &http.Cookie{
			Name:       c.Name,
			Value:      c.Value,
			Path:       c.Path,
			Domain:     c.Domain,
			Expires:    c.Expires,
			RawExpires: c.RawExpires,
			MaxAge:     c.MaxAge,
			Secure:     c.Secure,
			HttpOnly:   c.HttpOnly,
			SameSite:   http.SameSite(c.SameSite),
			Raw:        c.Raw,
			Unparsed:   c.Unparsed,
		}
	}
	j.jar.SetCookies(u, httpCookies)
}

func (j *CookieJarAdapter) Cookies(u *url.URL) []*fhttp.Cookie {
	httpCookies := j.jar.Cookies(u)
	fCookies := make([]*fhttp.Cookie, len(httpCookies))
	for i, c := range httpCookies {
		fCookies[i] = &fhttp.Cookie{
			Name:       c.Name,
			Value:      c.Value,
			Path:       c.Path,
			Domain:     c.Domain,
			Expires:    c.Expires,
			RawExpires: c.RawExpires,
			MaxAge:     c.MaxAge,
			Secure:     c.Secure,
			HttpOnly:   c.HttpOnly,
			SameSite:   fhttp.SameSite(c.SameSite),
			Raw:        c.Raw,
			Unparsed:   c.Unparsed,
		}
	}
	return fCookies
}

func GetProfile(id string) profiles.ClientProfile {
	switch id {
	case "chrome_103":
		return profiles.Chrome_103
	case "chrome_104":
		return profiles.Chrome_104
	case "chrome_105":
		return profiles.Chrome_105
	case "chrome_106":
		return profiles.Chrome_106
	case "chrome_107":
		return profiles.Chrome_107
	case "chrome_108":
		return profiles.Chrome_108
	case "chrome_109":
		return profiles.Chrome_109
	case "chrome_110":
		return profiles.Chrome_110
	case "chrome_111":
		return profiles.Chrome_111
	case "chrome_112":
		return profiles.Chrome_112
	case "chrome_117":
		return profiles.Chrome_117
	case "chrome_120":
		return profiles.Chrome_120
	case "firefox_102":
		return profiles.Firefox_102
	case "firefox_104":
		return profiles.Firefox_104
	case "firefox_105":
		return profiles.Firefox_105
	case "firefox_106":
		return profiles.Firefox_106
	case "firefox_108":
		return profiles.Firefox_108
	case "firefox_110":
		return profiles.Firefox_110
	case "safari_15_6_1":
		return profiles.Safari_15_6_1
	case "safari_16_0":
		return profiles.Safari_16_0
	case "safari_ios_15_5":
		return profiles.Safari_IOS_15_5
	case "safari_ios_15_6":
		return profiles.Safari_IOS_15_6
	case "safari_ios_16_0":
		return profiles.Safari_IOS_16_0
	case "opera_89":
		return profiles.Opera_89
	case "opera_90":
		return profiles.Opera_90
	case "opera_91":
		return profiles.Opera_91
	default:
		return profiles.Chrome_120
	}
}

func httpToFhttp(req *http.Request) (*fhttp.Request, error) {
	fReq, err := fhttp.NewRequest(req.Method, req.URL.String(), req.Body)
	if err != nil {
		return nil, err
	}

	for k, vv := range req.Header {
		for _, v := range vv {
			fReq.Header.Add(k, v)
		}
	}
	
	if req.Host != "" {
		fReq.Host = req.Host
	}

	return fReq, nil
}

func fhttpToHttp(fResp *fhttp.Response) *http.Response {
	resp := &http.Response{
		Status:           fResp.Status,
		StatusCode:       fResp.StatusCode,
		Proto:            fResp.Proto,
		ProtoMajor:       fResp.ProtoMajor,
		ProtoMinor:       fResp.ProtoMinor,
		ContentLength:    fResp.ContentLength,
		TransferEncoding: fResp.TransferEncoding,
		Close:            fResp.Close,
		Uncompressed:     fResp.Uncompressed,
		Trailer:          http.Header{},
		Header:           http.Header{},
		Body:             fResp.Body,
	}

	for k, vv := range fResp.Header {
		for _, v := range vv {
			resp.Header.Add(k, v)
		}
	}

	for k, vv := range fResp.Trailer {
		for _, v := range vv {
			resp.Trailer.Add(k, v)
		}
	}

	return resp
}
