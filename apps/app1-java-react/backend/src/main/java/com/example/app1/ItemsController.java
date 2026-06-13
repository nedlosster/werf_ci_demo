package com.example.app1;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/v1")
public class ItemsController {

    private final JdbcTemplate jdbc;

    public ItemsController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping("/items")
    public List<Map<String, Object>> items() {
        return jdbc.queryForList("SELECT id, name, note FROM items ORDER BY id");
    }
}
