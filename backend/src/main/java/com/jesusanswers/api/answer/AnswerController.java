package com.jesusanswers.api.answer;

import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import com.jesusanswers.api.answer.AnswerDtos.AnswerRequest;
import com.jesusanswers.api.answer.AnswerDtos.AnswerResponse;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;

@RestController
public class AnswerController {

    private final AnswerService answers;
    private final RateLimiter rateLimiter;

    public AnswerController(AnswerService answers, RateLimiter rateLimiter) {
        this.answers = answers;
        this.rateLimiter = rateLimiter;
    }

    /** Works signed in or anonymous; signed-in users are rate-limited per account, others per IP. */
    @PostMapping("/v1/answers")
    public AnswerResponse answer(@Valid @RequestBody AnswerRequest request, HttpServletRequest http) {
        String caller = http.getUserPrincipal() != null ? "user:" + http.getUserPrincipal().getName()
                : "ip:" + http.getRemoteAddr();
        rateLimiter.check(caller);
        return answers.answer(request);
    }

    /** 503 tells the app to fall back to its offline answer. */
    @ExceptionHandler(LlmClient.LlmUnavailableException.class)
    ProblemDetail unavailable() {
        return ProblemDetail.forStatusAndDetail(HttpStatus.SERVICE_UNAVAILABLE, "Answer temporarily unavailable");
    }

    @ExceptionHandler(RateLimiter.LimitExceededException.class)
    ProblemDetail tooMany() {
        return ProblemDetail.forStatusAndDetail(HttpStatus.TOO_MANY_REQUESTS, "Please wait a little and try again");
    }
}
